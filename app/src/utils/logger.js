/**
 * Structured JSON logger
 * Mỗi event là một dòng JSON trên stdout/stderr.
 * Không ghi password, token hoặc dữ liệu nhạy cảm.
 */

function formatLog(level, event, data) {
  return JSON.stringify({
    level,
    event,
    ...data,
    timestamp: new Date().toISOString(),
  });
}

const logger = {
  info(event, data = {}) {
    console.log(formatLog('INFO', event, data));
  },
  warn(event, data = {}) {
    console.warn(formatLog('WARN', event, data));
  },
  error(event, data = {}) {
    console.error(formatLog('ERROR', event, data));
  },
};

module.exports = logger;
