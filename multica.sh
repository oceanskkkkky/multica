#!/usr/bin/env bash
#
# multica 控制脚本（supervisor 薄封装，无 Docker）
# 实际由 supervisor 托管: multica-postgres / multica-backend / multica-frontend
# 用法:
#   ./multica.sh start    启动全部（supervisor 接管，含崩溃自恢复）
#   ./multica.sh stop     停止全部
#   ./multica.sh restart  重启全部
#   ./multica.sh status   查看状态
#   ./multica.sh logs     尾部日志（backend / frontend / postgres）
#
SUP_CONF="/etc/supervisord.conf"
PROGS="multica-postgres multica-backend multica-frontend"

green()  { printf '\033[32m%s\033[0m\n' "$1"; }
red()    { printf '\033[31m%s\033[0m\n' "$1"; }

if ! command -v supervisorctl >/dev/null 2>&1; then
  red "supervisor 未安装，请先: dnf install -y supervisor"
  exit 1
fi

case "${1:-status}" in
  start)
    supervisorctl -c "$SUP_CONF" start $PROGS
    sleep 2
    "$0" status
    ;;
  stop)
    supervisorctl -c "$SUP_CONF" stop $PROGS
    "$0" status
    ;;
  restart)
    supervisorctl -c "$SUP_CONF" restart $PROGS
    sleep 2
    "$0" status
    ;;
  status)
    supervisorctl -c "$SUP_CONF" status
    echo "--- 存活检查 ---"
    su - postgres -c "/usr/pgsql-17/bin/pg_isready -h 127.0.0.1 -p 5432" 2>/dev/null | grep -q "accepting connections" && green "postgres  : 运行中 (5432)" || red "postgres  : 未运行"
    curl -sf -o /dev/null "http://localhost:8080/health" 2>/dev/null && green "backend   : 运行中 (:8080)" || red "backend   : 未运行"
    curl -sf -o /dev/null "http://localhost:3000" 2>/dev/null && green "frontend  : 运行中 (:3000)" || red "frontend  : 未运行"
    ;;
  logs)
    echo "===== backend (tail) ====="; tail -n 40 /var/log/supervisor/multica-backend.err.log
    echo "===== frontend (tail) ====="; tail -n 40 /var/log/supervisor/multica-frontend.out.log
    echo "===== postgres (tail) ====="; tail -n 20 /var/log/supervisor/multica-postgres.err.log
    ;;
  *)
    echo "用法: $0 {start|stop|restart|status|logs}"
    exit 1
    ;;
esac
