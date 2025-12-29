# Operational Runbooks

This directory contains step-by-step operational procedures for managing the log storage and analytics application services.

## Available Runbooks

- **[weekly-app-shutdown-for-backup.md](weekly-app-shutdown-for-backup.md)** - Weekly application shutdown procedure for database backup
- **[monthly-app-update.md](monthly-app-update.md)** - Monthly application update and deployment procedure
- **[emergency-restart.md](emergency-restart.md)** - Emergency restart procedures for service failures
- **[troubleshooting-common-issues.md](troubleshooting-common-issues.md)** - Common issues and solutions during operations

## Quick Start for New Operators

If you're new to this system, start here:

1. Read [../OPERATOR_QUICK_START.md](../OPERATOR_QUICK_START.md) for basic commands
2. Shadow an experienced operator during a weekly backup
3. Review the troubleshooting guide before your first solo operation
4. Keep PagerDuty/Slack channels handy for escalation

## Runbook Conventions

### Symbols Used

- ✅ **Success indicator** - What good output looks like
- ❌ **Failure indicator** - What to watch out for
- ⚠️ **Warning** - Important safety information
- 💡 **Tip** - Helpful hints and best practices

### Code Blocks

```bash
# Commands you should run look like this
# Always run from the ansible directory
cd /opt/ansible/fluffy-potato
ansible-playbook -i inventory/hosts orchestrate.yml -e service_action=status
```

```
Expected output looks like this
PLAY RECAP: ok=5 changed=0 failed=0
```

### Time Estimates

Each runbook includes:
- **Duration**: Total time for procedure
- **Downtime**: How long services are unavailable
- **When**: Recommended maintenance window

## Emergency Contacts

Update these for your environment:

- **On-call Ops Engineer**: PagerDuty
- **Database Team**: Slack #database-team
- **Platform Team**: Slack #platform-ops
- **Management Escalation**: [Update with contact info]

## Maintenance Windows

Standard maintenance windows (update for your timezone):

- **Weekly Backup**: Saturday 22:00-23:00 PST
- **Monthly Updates**: First Sunday 02:00-04:00 PST
- **Emergency Maintenance**: Coordinate via Slack #ops-maintenance

## Pre-Flight Checklist (All Operations)

Before any maintenance operation:

- [ ] Verify you're in the approved maintenance window
- [ ] Check monitoring dashboard for active alerts
- [ ] Post notification in Slack #ops-maintenance
- [ ] Have escalation contacts available
- [ ] Backup team is ready (for backup operations)
- [ ] Rollback plan identified (for updates)

## Post-Operation Checklist (All Operations)

After any maintenance operation:

- [ ] Verify all services returned to expected state
- [ ] Check monitoring dashboard for new alerts
- [ ] Review email workflow report for any warnings
- [ ] Update maintenance ticket/change request
- [ ] Post completion notification in Slack
- [ ] Document any deviations or issues

## Training Requirements

New operators should complete:

1. **Week 1**: Read all runbooks, shadow experienced operator
2. **Week 2**: Perform operations with supervision
3. **Week 3**: Perform 2 successful supervised operations
4. **Week 4**: Independent operations with on-call backup

## Revision History

| Date | Author | Changes |
|------|--------|---------|
| 2025-12-26 | Initial | Created runbook structure |

---

**Last Updated**: 2025-12-26
