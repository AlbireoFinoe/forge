"""Offline tests for the disposable harness, including Python optimized mode."""

from contextlib import ExitStack
import importlib.util
import json
from pathlib import Path
import sys
from types import SimpleNamespace
import unittest
from unittest.mock import Mock, patch


spec = importlib.util.spec_from_file_location(
    "phase5d_postgres_validation",
    Path(__file__).with_name("phase5d_postgres_validation.py"),
)
harness = importlib.util.module_from_spec(spec)
spec.loader.exec_module(harness)


class DisposableSafetyTests(unittest.TestCase):
    def setUp(self):
        stack = self.enterContext(ExitStack())
        for module, name in (
            (harness.subprocess, "run"),
            (harness.socket, "socket"),
            (harness.psycopg, "connect"),
            (harness.sa, "create_engine"),
            (harness.command, "upgrade"),
            (harness.command, "downgrade"),
        ):
            stack.enter_context(
                patch.object(module, name, side_effect=AssertionError(f"Unexpected {name}"))
            )
        self.run = harness.DisposableRun("mock-docker")
        self.run.cid = "a" * 64
        self.run.fingerprint = [harness.MAIN, harness.ROLE, "123456789"]
        self.run.cli = Mock()

    def docker_inspection(self, index=None, replacement=None):
        values = [
            self.run.cid,
            f"/{harness.NAME}",
            {harness.LABEL: self.run.label},
            {harness.PGDATA: "rw,size=384m"},
            {"5432/tcp": [{"HostIp": harness.HOST, "HostPort": str(harness.PORT)}]},
            True,
            [{"Type": "tmpfs", "Destination": harness.PGDATA}],
        ]
        if index is not None:
            values[index] = replacement
        self.run.cli.return_value = SimpleNamespace(stdout=" ".join(map(json.dumps, values)))

    def database_driver(self, **changes):
        identity = {
            "database": harness.MAIN,
            "role": harness.ROLE,
            "schema": "public",
            "fingerprint": self.run.fingerprint[2],
            "address": "172.17.0.2",
            "port": 5432,
        }
        identity.update(changes)
        driver = Mock()
        cursor = Mock()
        cursor.fetchone.return_value = tuple(identity.values())
        driver.cursor.return_value.__enter__ = Mock(return_value=cursor)
        driver.cursor.return_value.__exit__ = Mock(return_value=False)
        driver.__enter__ = Mock(return_value=driver)
        driver.__exit__ = Mock(return_value=False)
        return driver

    def test_valid_synthetic_identities_pass(self):
        self.docker_inspection()
        self.run.verify_container()
        self.run.verify_server(self.database_driver(), harness.MAIN)

    def test_import_does_not_start_validation(self):
        imported = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(imported)
        harness.subprocess.run.assert_not_called()
        harness.psycopg.connect.assert_not_called()
        harness.sa.create_engine.assert_not_called()
        harness.command.upgrade.assert_not_called()
        harness.command.downgrade.assert_not_called()

    def test_wrong_container_identity_aborts_before_connection(self):
        for index, replacement in ((0, "b" * 64), (1, "/forge_postgres"), (2, {})):
            with self.subTest(index=index):
                self.docker_inspection(index, replacement)
                with self.assertRaises(RuntimeError):
                    self.run.create_second_database()
        harness.psycopg.connect.assert_not_called()

    def test_wrong_port_missing_tmpfs_or_foreign_mount_aborts_migration(self):
        engine = Mock(url=self.run.url(harness.MAIN))
        self.run.engines.append(engine)
        for index, replacement, reason in (
            (3, {}, "running with tmpfs"),
            (4, {"5432/tcp": [{"HostIp": "0.0.0.0", "HostPort": "5432"}]}, "port binding"),
            (5, False, "running with tmpfs"),
            (6, [{"Type": "volume", "Name": "forge-data"}], "non-tmpfs mount"),
        ):
            with self.subTest(index=index):
                self.docker_inspection(index, replacement)
                with self.assertRaisesRegex(RuntimeError, reason):
                    harness.migrate(
                        self.run, SimpleNamespace(), engine, harness.MAIN, "upgrade", harness.HEAD
                    )
        harness.command.upgrade.assert_not_called()

    def test_disallowed_database_aborts_before_engine_creation(self):
        for name in ("forge", "forge_workout_test", "forge_workout_integration_test"):
            with self.subTest(database=name):
                with self.assertRaises(RuntimeError):
                    self.run.credentials(name)
                with self.assertRaises(RuntimeError):
                    self.run.engine(name)
        harness.sa.create_engine.assert_not_called()

    def test_migration_rejects_an_unregistered_or_wrong_database_engine(self):
        self.docker_inspection()
        wrong = Mock(url=self.run.url(harness.DOWN))
        self.run.engines.append(wrong)
        unregistered = Mock(url=self.run.url(harness.MAIN))
        for engine in (wrong, unregistered):
            with self.subTest(engine=engine):
                with self.assertRaisesRegex(RuntimeError, "Migration engine"):
                    harness.migrate(
                        self.run, SimpleNamespace(), engine, harness.MAIN, "upgrade", harness.HEAD
                    )
        harness.command.upgrade.assert_not_called()

    def test_migration_uses_verified_container_and_registered_engine(self):
        self.docker_inspection()
        engine = Mock(url=self.run.url(harness.MAIN))
        self.run.engines.append(engine)
        with patch.object(harness.command, "upgrade") as upgrade:
            harness.migrate(self.run, SimpleNamespace(), engine, harness.MAIN, "upgrade", harness.HEAD)
        upgrade.assert_called_once()
        self.assertEqual(upgrade.call_args.args[1], harness.HEAD)

    def test_database_identity_mismatch_aborts_before_create_database(self):
        self.docker_inspection()
        for field, wrong in (
            ("database", "forge"),
            ("role", "postgres"),
            ("schema", "unexpected"),
            ("fingerprint", "987654321"),
            ("address", None),
            ("port", 6543),
        ):
            with self.subTest(field=field):
                driver = self.database_driver(**{field: wrong})
                with patch.object(harness.psycopg, "connect", return_value=driver):
                    with self.assertRaises(RuntimeError):
                        self.run.create_second_database()
                driver.execute.assert_not_called()

    def test_missing_identity_aborts_before_create_database(self):
        self.docker_inspection()
        driver = self.database_driver()
        driver.cursor.return_value.__enter__.return_value.fetchone.return_value = None
        with patch.object(harness.psycopg, "connect", return_value=driver):
            with self.assertRaisesRegex(RuntimeError, "no server identity"):
                self.run.create_second_database()
        driver.execute.assert_not_called()

    def test_transaction_guard_rejects_fingerprint_mismatch_before_write(self):
        driver = self.database_driver(fingerprint="987654321")
        connection = SimpleNamespace(connection=SimpleNamespace(driver_connection=driver))
        engine = Mock()

        def capture(event_target, event_name):
            self.assertIs(event_target, engine)
            self.assertEqual(event_name, "begin")

            def register(listener):
                engine.begin.side_effect = lambda: listener(connection)
                return listener

            return register

        with (
            patch.object(harness.sa, "create_engine", return_value=engine),
            patch.object(harness.sa.event, "listens_for", side_effect=capture),
        ):
            guarded = self.run.engine(harness.MAIN)
            with self.assertRaises(RuntimeError):
                guarded.begin()
                guarded.execute("simulated write")
        guarded.execute.assert_not_called()

    def test_wrong_cleanup_identity_never_calls_rm(self):
        self.docker_inspection(2, {harness.LABEL: "another-run"})
        with self.assertRaises(RuntimeError):
            self.run.close()
        self.run.cli.assert_called_once()
        self.assertEqual(self.run.cli.call_args.args[0], "inspect")

    def test_verified_cleanup_calls_rm_with_exact_container_id(self):
        self.docker_inspection()
        with patch("builtins.print"):
            self.run.close()
        self.assertEqual(self.run.cli.call_args_list[1].args, ("rm", "-f", self.run.cid))

    def test_docker_start_checks_engine_and_name_before_run(self):
        for responses in (["windows"], ["linux", "preexisting-container"]):
            with self.subTest(responses=responses):
                self.run.cli.reset_mock()
                self.run.cli.side_effect = [SimpleNamespace(stdout=value) for value in responses]
                with self.assertRaises(RuntimeError):
                    self.run.start()
                self.assertEqual(self.run.cli.call_count, len(responses))
                self.assertNotIn("run", [entry.args[0] for entry in self.run.cli.call_args_list])


if __name__ == "__main__":
    print(f"Python optimization level: {sys.flags.optimize}", flush=True)
    unittest.main()
