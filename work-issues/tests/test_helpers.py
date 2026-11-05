import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

SCRIPTS = Path(__file__).resolve().parents[1] / 'scripts'


class Helpers(unittest.TestCase):
    def test_shared_lock_and_failed_update(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            state = root / 'reservations.json'
            state.write_text('{"owners": []}')
            lock = root / 'coordination.lock'
            processes = []
            for number in range(8):
                run = root / str(number)
                run.mkdir()
                helper = run / 'coord.py'
                helper.write_text((SCRIPTS / 'coord.py').read_text())
                expression = f'import time; time.sleep(.02); d["owners"].append({number})'
                processes.append(subprocess.Popen(['python3', str(helper), str(state), expression, '--lock', str(lock)]))
            self.assertTrue(all(process.wait() == 0 for process in processes))
            self.assertEqual(sorted(json.loads(state.read_text())['owners']), list(range(8)))
            before = state.read_text()
            result = subprocess.run(['python3', str(SCRIPTS / 'coord.py'), str(state), 'd.clear(); raise ValueError("interrupted")', '--lock', str(lock)], capture_output=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(state.read_text(), before)

    def test_reservation_check_and_claim_are_serialized(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            state = root / 'reservations.json'
            state.write_text('{"claims": []}')
            processes = []
            for number in range(6):
                expression = f'import time; available = "file.py" not in d; time.sleep(.02); (d.update({{"file.py": {number}}}), d["claims"].append({number})) if available else None'
                processes.append(subprocess.Popen(['python3', str(SCRIPTS / 'coord.py'), str(state), expression, '--lock', str(root / 'coordination.lock')]))
            self.assertTrue(all(process.wait() == 0 for process in processes))
            self.assertEqual(len(json.loads(state.read_text())['claims']), 1)

    def observe(self, mode):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'state.json').write_text(json.dumps({'repo': 'org/repo', 'login': 'tester'}))
            (root / 'prs.txt').write_text('1\n')
            gh = root / 'gh'
            gh.write_text('''#!/bin/bash
case "$*" in
  *"--json state,headRefOid"*) echo "OPEN aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" ;;
  *"--json headRefOid"*)
    if [ "$CASE" = changed ]; then echo bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb; else echo aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa; fi ;;
  *"pulls/1/reviews"*) [ "$CASE" != api_failure ] || exit 1 ;;
  *"pulls/1/comments"*|*"issues/1/comments"*) ;;
  *"pr checks"*)
    case "$CASE" in
      cancelled) echo '[{"name":"test","bucket":"cancel"}]' ;;
      pending) echo '[{"name":"test","bucket":"pending"}]'; exit 8 ;;
      *) echo '[{"name":"test","bucket":"pass"}]' ;;
    esac ;;
  *) exit 2 ;;
esac
''')
            gh.chmod(0o755)
            env = dict(os.environ, PATH=str(root) + os.pathsep + os.environ['PATH'], ONCE='1', CASE=mode)
            result = subprocess.run(['bash', str(SCRIPTS / 'watch.sh'), str(root)], env=env, capture_output=True, text=True, timeout=10)
            self.assertEqual(result.returncode, 0, result.stderr)
            return result.stdout

    def test_cancelled_checks_are_failures(self):
        output = self.observe('cancelled')
        self.assertIn('done-with-failures', output)
        self.assertNotIn('completed-without-failures', output)

    def test_api_failure_is_not_success(self):
        output = self.observe('api_failure')
        self.assertIn('monitoring-error', output)
        self.assertNotIn('completed-without-failures', output)

    def test_head_change_requires_refresh(self):
        output = self.observe('changed')
        self.assertIn('head changed', output)
        self.assertNotIn('completed-without-failures', output)

    def test_pending_checks_do_not_complete(self):
        self.assertNotIn('completed-without-failures', self.observe('pending'))

    def test_passed_checks_are_only_check_completion(self):
        self.assertIn('checks completed-without-failures', self.observe('passed'))


if __name__ == '__main__':
    unittest.main()
