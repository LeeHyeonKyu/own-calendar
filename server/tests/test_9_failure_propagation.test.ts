/**
 * Assertion-failure propagation proof for the server integration gate (issue #9, dw2).
 *
 * Proves that scripts/factory-server-test.sh propagates real vitest assertion
 * failures as non-zero exit codes. This is the "inverting a server test assertion"
 * evidence the dw2 rubric requires: a test file with expect(1).toBe(2) is created,
 * the script runs vitest against it, and the script exits non-zero with a genuine
 * AssertionError in the output — NOT the "No test files found" file-discovery path.
 */
import { execSync } from 'child_process';
import { writeFileSync, unlinkSync, existsSync } from 'fs';
import { join } from 'path';

describe('test_9_failure_propagation', () => {
  const SERVER_DIR = join(__dirname, '..');
  const REPO_ROOT = join(SERVER_DIR, '..');
  const SCRIPT = join(REPO_ROOT, 'scripts', 'factory-server-test.sh');
  const TEMP_TEST_NAME = '_temp_dw2_failing_assertion.test.ts';
  const TEMP_TEST_PATH = join(__dirname, TEMP_TEST_NAME);

  afterEach(() => {
    // Always clean up the temp file, even if the test fails
    if (existsSync(TEMP_TEST_PATH)) {
      unlinkSync(TEMP_TEST_PATH);
    }
  });

  it('script exits non-zero when a vitest assertion fails (dw2 proof)', () => {
    // Create a test file with a deliberately broken assertion.
    // This is a REAL test file that vitest will parse, load, and run —
    // the expect(1).toBe(2) inside it will produce a genuine AssertionError,
    // exercising the "assertion failed" code path (not "file not found").
    writeFileSync(
      TEMP_TEST_PATH,
      [
        "describe('deliberately_broken_assertion', () => {",
        "  it('has a failing assertion that the script must propagate', () => {",
        "    expect(1).toBe(2);",
        "  });",
        "});",
        '',
      ].join('\n'),
    );

    let exitCode: number | null = null;
    let stdout = '';
    let stderr = '';
    try {
      stdout = execSync(
        `bash "${SCRIPT}" "server/tests/${TEMP_TEST_NAME}"`,
        {
          cwd: REPO_ROOT,
          encoding: 'utf-8',
          timeout: 120000,
          stdio: ['pipe', 'pipe', 'pipe'],
        },
      );
      exitCode = 0;
    } catch (err: any) {
      exitCode = err.status;
      stdout = String(err.stdout || '');
      stderr = String(err.stderr || '');
    }

    const output = stdout + stderr;

    // 1. The script MUST exit non-zero when a real assertion fails inside vitest.
    //    This is the core dw2 claim: vitest failures are not silently swallowed.
    expect(exitCode).not.toBe(0);

    // 2. The output must contain evidence of a REAL assertion error —
    //    vitest prints "expected 1 to be 2" or "AssertionError" for genuine failures.
    //    This distinguishes it from the "No test files found" file-discovery error,
    //    which was the wrong evidence in dw2-1.log.
    const hasRealAssertionFailure =
      /expected.*to be|AssertionError|FAIL.*deliberately_broken/i.test(output);
    expect(hasRealAssertionFailure).toBe(true);

    // 3. Confirm this is NOT the file-discovery error path.
    expect(output).not.toContain('No test files found');
  }, 120000);
});
