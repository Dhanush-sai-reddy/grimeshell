# Project Map

All projects live under `/home/dhanushsr/Downloads/mygit/`.

## Active Projects

### Train-Ticket-booking-system
- **Path**: /home/dhanushsr/Downloads/mygit/Train-Ticket-booking-system
- **Tech**: Node.js, Prisma ORM
- **Branch**: main
- **Status**: Active
- **Notes**: Has git, npm, prisma permissions configured

### fullcalendar
- **Path**: /home/dhanushsr/Downloads/mygit/fullcalendar
- **Branch**: main
- **Status**: Active

### flfullstack
- **Path**: /home/dhanushsr/Downloads/mygit/flfullstack
- **Branch**: master
- **Status**: Active

### cachy-configs
- **Path**: /home/dhanushsr/Downloads/mygit/cachy-configs
- **Branch**: main
- **Status**: Active
- **Notes**: CachyOS system configuration files

### Unified-campus-resource-and-event-management
- **Path**: /home/dhanushsr/Downloads/mygit/Unified-campus-resource-and-event-management
- **Status**: Active
- **Notes**: Has git permissions configured

### neocodeium
- **Path**: /home/dhanushsr/Downloads/mygit/neocodeium
- **Branch**: main
- **Status**: Active

### SHELLLL (This Repo)
- **Path**: /home/dhanushsr/Downloads/mygit/SHELLLL
- **Branch**: master
- **Status**: Active — Brain repository
- **Purpose**: Default context and skills for all terminal-launched AI agents

## Project Discovery

To add new projects to this map, run from the mygit directory:
```bash
for dir in /home/dhanushsr/Downloads/mygit/*/; do
  if [ -d "$dir/.git" ]; then
    branch=$(git -C "$dir" branch --show-current 2>/dev/null || echo "unknown")
    echo "- $(basename "$dir") [$branch]"
  fi
done
```
