/**
 * Minimal JSON-line logger (issue #51).
 *
 * Exports `logger.info(msg, meta?)`, `logger.warn(msg, meta?)`, `logger.error(msg, meta?)`.
 * Each call writes one JSON line to stdout (info) or stderr (warn, error).
 *
 * Respects the `LOG_LEVEL` env var at call time:
 *   - "info"   (default): info, warn, error
 *   - "warn":  warn, error
 *   - "error": error only
 *   - "silent": nothing
 *
 * No runtime dependency — uses only Node built-ins.
 */

type LogLevel = 'info' | 'warn' | 'error' | 'silent';

const LEVEL_PRIORITY: Record<LogLevel, number> = {
  info: 0,
  warn: 1,
  error: 2,
  silent: 3,
};

function currentLevel(): LogLevel {
  const raw = process.env.LOG_LEVEL?.toLowerCase();
  if (raw && raw in LEVEL_PRIORITY) return raw as LogLevel;
  return 'info';
}

function shouldLog(msgLevel: LogLevel): boolean {
  return LEVEL_PRIORITY[msgLevel] >= LEVEL_PRIORITY[currentLevel()];
}

function serializeMeta(meta: unknown): Record<string, unknown> {
  if (meta instanceof Error) {
    return {
      error: meta.message,
      stack: meta.stack,
    };
  }
  if (meta !== null && typeof meta === 'object' && !Array.isArray(meta)) {
    return meta as Record<string, unknown>;
  }
  if (meta !== undefined) {
    return { meta };
  }
  return {};
}

function write(
  level: LogLevel,
  stream: NodeJS.WriteStream,
  msg: string,
  meta?: unknown,
): void {
  if (!shouldLog(level)) return;

  const entry: Record<string, unknown> = {
    level,
    msg,
    time: new Date().toISOString(),
    ...serializeMeta(meta),
  };

  stream.write(JSON.stringify(entry) + '\n');
}

export const logger = {
  info(msg: string, meta?: unknown): void {
    write('info', process.stdout, msg, meta);
  },

  warn(msg: string, meta?: unknown): void {
    write('warn', process.stderr, msg, meta);
  },

  error(msg: string, meta?: unknown): void {
    write('error', process.stderr, msg, meta);
  },
};
