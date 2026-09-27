/**
 * Tests for server/src/lib/logger.ts (issue #51).
 *
 * Naming: test_51_<slug> per harness convention.
 * Covers done_when dw1 (level filtering, JSON format, silent mode, no new dep)
 * and dw4 (Error metadata serialization).
 */
import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';

describe('test_51_logger_levels', () => {
  let originalLogLevel: string | undefined;

  beforeEach(() => {
    originalLogLevel = process.env.LOG_LEVEL;
  });

  afterEach(() => {
    // Restore LOG_LEVEL after each test so tests are order-independent
    if (originalLogLevel === undefined) {
      delete process.env.LOG_LEVEL;
    } else {
      process.env.LOG_LEVEL = originalLogLevel;
    }
    vi.restoreAllMocks();
  });

  it('logger.info writes a JSON line with level, msg, and time fields to stdout', async () => {
    delete process.env.LOG_LEVEL; // default = info
    // Re-import to pick up fresh env
    const { logger } = await import('../src/lib/logger');

    const stdoutSpy = vi.spyOn(process.stdout, 'write').mockImplementation(() => true);

    logger.info('hello world');

    expect(stdoutSpy).toHaveBeenCalledTimes(1);
    const written = stdoutSpy.mock.calls[0][0] as string;
    const parsed = JSON.parse(written);
    expect(parsed.level).toBe('info');
    expect(parsed.msg).toBe('hello world');
    expect(parsed.time).toBeDefined();
    // time should be a valid ISO-like timestamp
    expect(new Date(parsed.time).getTime()).not.toBeNaN();
  });

  it('logger.error writes to stderr', async () => {
    delete process.env.LOG_LEVEL;
    const { logger } = await import('../src/lib/logger');

    const stderrSpy = vi.spyOn(process.stderr, 'write').mockImplementation(() => true);

    logger.error('something broke');

    expect(stderrSpy).toHaveBeenCalledTimes(1);
    const written = stderrSpy.mock.calls[0][0] as string;
    const parsed = JSON.parse(written);
    expect(parsed.level).toBe('error');
    expect(parsed.msg).toBe('something broke');
    expect(parsed.time).toBeDefined();
  });

  it('logger.warn writes to stderr with level warn', async () => {
    delete process.env.LOG_LEVEL;
    const { logger } = await import('../src/lib/logger');

    const stderrSpy = vi.spyOn(process.stderr, 'write').mockImplementation(() => true);

    logger.warn('watch out');

    expect(stderrSpy).toHaveBeenCalledTimes(1);
    const written = stderrSpy.mock.calls[0][0] as string;
    const parsed = JSON.parse(written);
    expect(parsed.level).toBe('warn');
    expect(parsed.msg).toBe('watch out');
  });

  it('LOG_LEVEL=silent suppresses all output', async () => {
    process.env.LOG_LEVEL = 'silent';
    // Must re-import after env change for the module to pick it up
    const { logger } = await import('../src/lib/logger');

    const stdoutSpy = vi.spyOn(process.stdout, 'write').mockImplementation(() => true);
    const stderrSpy = vi.spyOn(process.stderr, 'write').mockImplementation(() => true);

    logger.info('should not appear');
    logger.warn('should not appear');
    logger.error('should not appear');

    expect(stdoutSpy).not.toHaveBeenCalled();
    expect(stderrSpy).not.toHaveBeenCalled();
  });

  it('LOG_LEVEL=warn suppresses info but allows warn and error', async () => {
    process.env.LOG_LEVEL = 'warn';
    const { logger } = await import('../src/lib/logger');

    const stdoutSpy = vi.spyOn(process.stdout, 'write').mockImplementation(() => true);
    const stderrSpy = vi.spyOn(process.stderr, 'write').mockImplementation(() => true);

    logger.info('should be filtered');
    logger.warn('should pass');
    logger.error('should pass');

    // info goes to stdout — should be suppressed
    expect(stdoutSpy).not.toHaveBeenCalled();
    // warn + error go to stderr — both should fire
    expect(stderrSpy).toHaveBeenCalledTimes(2);
  });

  it('LOG_LEVEL=error suppresses info and warn but allows error', async () => {
    process.env.LOG_LEVEL = 'error';
    const { logger } = await import('../src/lib/logger');

    const stdoutSpy = vi.spyOn(process.stdout, 'write').mockImplementation(() => true);
    const stderrSpy = vi.spyOn(process.stderr, 'write').mockImplementation(() => true);

    logger.info('should be filtered');
    logger.warn('should be filtered');
    logger.error('should pass');

    expect(stdoutSpy).not.toHaveBeenCalled();
    expect(stderrSpy).toHaveBeenCalledTimes(1);
    const written = stderrSpy.mock.calls[0][0] as string;
    const parsed = JSON.parse(written);
    expect(parsed.level).toBe('error');
  });

  it('logger.info includes extra metadata fields when provided', async () => {
    delete process.env.LOG_LEVEL;
    const { logger } = await import('../src/lib/logger');

    const stdoutSpy = vi.spyOn(process.stdout, 'write').mockImplementation(() => true);

    logger.info('with meta', { requestId: 'abc-123', userId: 42 });

    const written = stdoutSpy.mock.calls[0][0] as string;
    const parsed = JSON.parse(written);
    expect(parsed.msg).toBe('with meta');
    expect(parsed.requestId).toBe('abc-123');
    expect(parsed.userId).toBe(42);
  });
});

describe('test_51_error_meta', () => {
  afterEach(() => {
    vi.restoreAllMocks();
  });

  it('Error instance as metadata preserves message and stack trace', async () => {
    delete process.env.LOG_LEVEL;
    const { logger } = await import('../src/lib/logger');

    const stderrSpy = vi.spyOn(process.stderr, 'write').mockImplementation(() => true);

    const err = new Error('boom');
    logger.error('operation failed', err);

    expect(stderrSpy).toHaveBeenCalledTimes(1);
    const written = stderrSpy.mock.calls[0][0] as string;
    const parsed = JSON.parse(written);
    expect(parsed.msg).toBe('operation failed');
    // Must contain the error message — JSON.stringify(new Error()) === '{}' so naive impl fails
    expect(written).toContain('boom');
    // Must contain a stack trace fragment (file path or 'at ')
    expect(parsed.stack).toBeDefined();
    expect(parsed.stack).toContain('at ');
    // error field should carry the error message separately
    expect(parsed.error).toBe('boom');
  });

  it('non-Error metadata is spread into the JSON line as-is', async () => {
    delete process.env.LOG_LEVEL;
    const { logger } = await import('../src/lib/logger');

    const stderrSpy = vi.spyOn(process.stderr, 'write').mockImplementation(() => true);

    logger.error('db failure', { code: 'ECONNREFUSED', host: 'localhost' });

    const written = stderrSpy.mock.calls[0][0] as string;
    const parsed = JSON.parse(written);
    expect(parsed.code).toBe('ECONNREFUSED');
    expect(parsed.host).toBe('localhost');
  });
});
