#!/bin/bash

# Flight Tracker Remote Management Script
# Manages the Flight Tracker service on the remote "vpn" server via SSH

set -e

# Configuration
REMOTE_SERVER="vpn"
SERVICE_NAME="flight-tracker"
REMOTE_APP_DIR="/opt/flight-tracker"
REMOTE_USER="flightbot"
REMOTE_BACKUP_DIR="/opt/flight-tracker/backups"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# SSH helper function
ssh_exec() {
    local command="$1"
    local use_sudo="${2:-false}"
    
    if [[ "$use_sudo" == "true" ]]; then
        ssh "$REMOTE_SERVER" "sudo $command"
    else
        ssh "$REMOTE_SERVER" "$command"
    fi
}

# Service management functions
start_service() {
    log_info "Starting $SERVICE_NAME service on $REMOTE_SERVER..."
    ssh_exec "systemctl start $SERVICE_NAME" true
    log_success "Service started"
}

stop_service() {
    log_info "Stopping $SERVICE_NAME service on $REMOTE_SERVER..."
    ssh_exec "systemctl stop $SERVICE_NAME" true
    log_success "Service stopped"
}

restart_service() {
    log_info "Restarting $SERVICE_NAME service on $REMOTE_SERVER..."
    ssh_exec "systemctl restart $SERVICE_NAME" true
    log_success "Service restarted"
}

reload_service() {
    log_info "Reloading $SERVICE_NAME service on $REMOTE_SERVER..."
    ssh_exec "systemctl reload-or-restart $SERVICE_NAME" true
    log_success "Service reloaded"
}

enable_service() {
    log_info "Enabling $SERVICE_NAME service on $REMOTE_SERVER..."
    ssh_exec "systemctl enable $SERVICE_NAME" true
    log_success "Service enabled for auto-start"
}

disable_service() {
    log_info "Disabling $SERVICE_NAME service on $REMOTE_SERVER..."
    ssh_exec "systemctl disable $SERVICE_NAME" true
    log_success "Service disabled"
}

# Status and monitoring functions
show_status() {
    echo "=== Flight Tracker Service Status on $REMOTE_SERVER ==="
    ssh_exec "systemctl status $SERVICE_NAME --no-pager" false
    echo ""
    echo "=== Service Health Check ==="
    
    if ssh_exec "systemctl is-active --quiet $SERVICE_NAME" false; then
        log_success "Service is running"
    else
        log_error "Service is not running"
    fi
    
    if ssh_exec "systemctl is-enabled --quiet $SERVICE_NAME" false; then
        log_info "Service is enabled (auto-start)"
    else
        log_warning "Service is disabled (manual start)"
    fi
}

show_logs() {
    local lines=${1:-50}
    log_info "Showing last $lines lines of logs from $REMOTE_SERVER..."
    ssh_exec "journalctl -u $SERVICE_NAME -n $lines --no-pager" false
}

follow_logs() {
    log_info "Following logs from $REMOTE_SERVER (Ctrl+C to stop)..."
    ssh_exec "journalctl -u $SERVICE_NAME -f" false
}

show_errors() {
    local lines=${1:-20}
    log_info "Showing last $lines error/warning logs from $REMOTE_SERVER..."
    ssh_exec "journalctl -u $SERVICE_NAME -p warning -n $lines --no-pager" false
}

# Application management functions
show_app_info() {
    echo "=== Application Information on $REMOTE_SERVER ==="
    echo "Service: $SERVICE_NAME"
    echo "App Directory: $REMOTE_APP_DIR"
    echo "User: $REMOTE_USER"
    echo "Backup Directory: $REMOTE_BACKUP_DIR"
    echo ""
    
    log_info "Current Release:"
    ssh_exec "ls -la $REMOTE_APP_DIR/current/ 2>/dev/null | head -5 || echo 'No current release found'" false
    echo ""
    
    log_info "Release Information:"
    ssh_exec "cat $REMOTE_APP_DIR/current/releases/RELEASES 2>/dev/null || echo 'No release info found'" false
    echo ""
    
    log_info "Disk Usage:"
    ssh_exec "du -sh $REMOTE_APP_DIR/* 2>/dev/null || echo 'No data available'" false
}

# Backup functions
create_backup() {
    local backup_name="backup-$(date +%Y%m%d-%H%M%S)"
    local backup_path="$REMOTE_BACKUP_DIR/$backup_name"
    
    log_info "Creating backup: $backup_name on $REMOTE_SERVER"
    
    # Create backup directory if it doesn't exist
    ssh_exec "mkdir -p $REMOTE_BACKUP_DIR" true
    
    # Stop service for consistent backup
    log_info "Stopping service for backup..."
    ssh_exec "systemctl stop $SERVICE_NAME" true
    
    # Create backup
    ssh_exec "cp -r $REMOTE_APP_DIR/current $backup_path" true
    
    # Copy state file if it exists
    ssh_exec "if [[ -f $REMOTE_APP_DIR/flight_tracking_state.bin ]]; then cp $REMOTE_APP_DIR/flight_tracking_state.bin $backup_path/; fi" true
    
    # Restart service
    log_info "Restarting service..."
    ssh_exec "systemctl start $SERVICE_NAME" true
    
    log_success "Backup created: $backup_path"
}

list_backups() {
    echo "=== Available Backups on $REMOTE_SERVER ==="
    ssh_exec "if [[ -d $REMOTE_BACKUP_DIR ]]; then ls -la $REMOTE_BACKUP_DIR/; else echo 'No backup directory found'; fi" false
}

restore_backup() {
    local backup_name="$1"
    
    if [[ -z "$backup_name" ]]; then
        log_error "Please specify backup name"
        list_backups
        exit 1
    fi
    
    local backup_path="$REMOTE_BACKUP_DIR/$backup_name"
    
    # Check if backup exists
    if ! ssh_exec "test -d $backup_path" false; then
        log_error "Backup not found: $backup_path"
        exit 1
    fi
    
    log_warning "This will replace the current installation with backup: $backup_name"
    read -p "Are you sure? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_info "Stopping service..."
        ssh_exec "systemctl stop $SERVICE_NAME" true
        
        log_info "Restoring from backup..."
        ssh_exec "rm -rf $REMOTE_APP_DIR/current" true
        ssh_exec "cp -r $backup_path $REMOTE_APP_DIR/current" true
        ssh_exec "chown -R $REMOTE_USER:$REMOTE_USER $REMOTE_APP_DIR/current" true
        
        log_info "Starting service..."
        ssh_exec "systemctl start $SERVICE_NAME" true
        
        log_success "Backup restored successfully"
    else
        log_info "Restore cancelled"
    fi
}

# Health check functions
health_check() {
    echo "=== Flight Tracker Health Check on $REMOTE_SERVER ==="
    
    # Check service status
    if ssh_exec "systemctl is-active --quiet $SERVICE_NAME" false; then
        log_success "✓ Service is running"
    else
        log_error "✗ Service is not running"
        return 1
    fi
    
    # Check if process is responding
    local pid=$(ssh_exec "systemctl show --property MainPID --value $SERVICE_NAME" false)
    if [[ "$pid" != "0" ]] && ssh_exec "kill -0 $pid 2>/dev/null" false; then
        log_success "✓ Process is responding (PID: $pid)"
    else
        log_error "✗ Process is not responding"
        return 1
    fi
    
    # Check state file
    if ssh_exec "test -f $REMOTE_APP_DIR/flight_tracking_state.bin" false; then
        log_success "✓ State file exists"
    else
        log_warning "⚠ State file not found (new installation?)"
    fi
    
    # Check environment file
    if ssh_exec "test -f /etc/flight-tracker/flight-tracker.env" false; then
        log_success "✓ Environment file exists"
    else
        log_error "✗ Environment file missing"
        return 1
    fi
    
    # Check recent logs for errors
    local error_count=$(ssh_exec "journalctl -u $SERVICE_NAME --since '5 minutes ago' -p err --no-pager | wc -l" false)
    if [[ $error_count -eq 0 ]]; then
        log_success "✓ No recent errors in logs"
    else
        log_warning "⚠ Found $error_count errors in last 5 minutes"
    fi
    
    log_success "Health check completed"
}

# Configuration functions
edit_config() {
    log_info "Opening environment configuration on $REMOTE_SERVER..."
    ssh_exec "nano /etc/flight-tracker/flight-tracker.env" true
    
    read -p "Restart service to apply changes? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        restart_service
    fi
}

show_config() {
    echo "=== Configuration on $REMOTE_SERVER ==="
    log_info "Environment file contents (sensitive values hidden):"
    ssh_exec "if [[ -f /etc/flight-tracker/flight-tracker.env ]]; then sed 's/=.*/=***/' /etc/flight-tracker/flight-tracker.env; else echo 'Environment file not found'; fi" false
}

# Cleanup functions
cleanup_logs() {
    log_info "Cleaning up old logs on $REMOTE_SERVER..."
    ssh_exec "journalctl --vacuum-time=7d" true
    log_success "Log cleanup completed"
}

cleanup_backups() {
    local keep_days=${1:-30}
    log_info "Cleaning up backups older than $keep_days days on $REMOTE_SERVER..."
    
    ssh_exec "if [[ -d $REMOTE_BACKUP_DIR ]]; then find $REMOTE_BACKUP_DIR -type d -name 'backup-*' -mtime +$keep_days -exec rm -rf {} \\;; echo 'Backup cleanup completed'; else echo 'No backup directory found'; fi" true
}

# Deployment function
deploy() {
    log_info "Running deployment to $REMOTE_SERVER..."
    if [[ -f "./deploy.sh" ]]; then
        ./deploy.sh
    else
        log_error "deploy.sh script not found in current directory"
        exit 1
    fi
}

# System stats function
show_stats() {
    echo "=== System Stats on $REMOTE_SERVER ==="
    log_info "Process information:"
    ssh_exec "ps aux | grep flight_tracker | grep -v grep || echo 'Service not running'" false
    echo ""
    
    log_info "Disk usage:"
    ssh_exec "df -h $REMOTE_APP_DIR 2>/dev/null || echo 'App directory not found'" false
    echo ""
    
    log_info "State file info:"
    ssh_exec "ls -la $REMOTE_APP_DIR/flight_tracking_state.bin 2>/dev/null || echo 'No state file found'" false
    echo ""
    
    log_info "Memory usage:"
    ssh_exec "free -h" false
}

# Help function
show_help() {
    cat << EOF
Flight Tracker Remote Management Script

Manages the Flight Tracker service on remote server: $REMOTE_SERVER

Usage: $0 <command> [options]

Service Management:
  start           Start the service
  stop            Stop the service
  restart         Restart the service
  reload          Reload the service
  enable          Enable auto-start
  disable         Disable auto-start

Monitoring:
  status          Show service status
  logs [lines]    Show recent logs (default: 50 lines)
  follow          Follow logs in real-time
  errors [lines]  Show recent errors (default: 20 lines)
  health          Run health check
  stats           Show system statistics

Application:
  info            Show application information
  config          Show configuration
  edit-config     Edit environment configuration

Backup & Restore:
  backup          Create a backup
  list-backups    List available backups
  restore <name>  Restore from backup

Maintenance:
  cleanup-logs    Clean up old logs (keep 7 days)
  cleanup-backups [days]  Clean up old backups (default: 30 days)
  deploy          Run deployment script

Examples:
  $0 status                    # Show service status
  $0 logs 100                  # Show last 100 log lines
  $0 backup                    # Create a backup
  $0 restore backup-20240101-120000  # Restore specific backup
  $0 deploy                    # Deploy latest version
  $0 stats                     # Show system statistics

Note: This script connects to '$REMOTE_SERVER' via SSH. Ensure you have SSH access configured.

EOF
}

# Main command processing
main() {
    case "${1:-}" in
        "start")
            start_service
            ;;
        "stop")
            stop_service
            ;;
        "restart")
            restart_service
            ;;
        "reload")
            reload_service
            ;;
        "enable")
            enable_service
            ;;
        "disable")
            disable_service
            ;;
        "status")
            show_status
            ;;
        "logs")
            show_logs "${2:-50}"
            ;;
        "follow")
            follow_logs
            ;;
        "errors")
            show_errors "${2:-20}"
            ;;
        "health")
            health_check
            ;;
        "info")
            show_app_info
            ;;
        "config")
            show_config
            ;;
        "edit-config")
            edit_config
            ;;
        "backup")
            create_backup
            ;;
        "list-backups")
            list_backups
            ;;
        "restore")
            restore_backup "$2"
            ;;
        "cleanup-logs")
            cleanup_logs
            ;;
        "cleanup-backups")
            cleanup_backups "${2:-30}"
            ;;
        "deploy")
            deploy
            ;;
        "stats")
            show_stats
            ;;
        "help"|"-h"|"--help"|"")
            show_help
            ;;
        *)
            log_error "Unknown command: $1"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@" 