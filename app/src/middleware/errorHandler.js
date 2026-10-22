const logger = require('../utils/logger');

/**
 * Global error handler — không lộ stack trace cho client.
 */
function errorHandler(err, req, res, _next) {
  logger.error('unhandled_error', {
    message: err.message,
    path:    req.path,
    method:  req.method,
  });

  const status = err.status || 500;
  res.status(status).render('error', {
    title:   'Lỗi',
    message: status === 404
      ? 'Trang bạn tìm kiếm không tồn tại.'
      : 'Đã xảy ra lỗi hệ thống. Vui lòng thử lại sau.',
    status,
    active: '',
  });
}

module.exports = errorHandler;
