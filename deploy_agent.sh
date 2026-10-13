#!/bin/bash
#Writing the frame of deploy_agent.sh a menu that loops until you choose Exit with an empty function for each feature

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR" || exit 1
TEMPLATE_DIR="$SCRIPT_DIR/templates"
deploy() {
    echo ">> Deploy feature (not built yet)"
}
run_app() {
    echo ">> Run feature (not built yet)"
}
archive_logs() {
    echo ">> Archive feature (not built yet)"
}
show_menu() {
    echo "   Attendance Tracker Agent"
    echo "  1) Deploy a new project"
    echo "  2) Run an existing project"
    echo "  3) Archive logs"
    echo "  4) Exit"
}
main() {
    while true; do
        show_menu
        read -r -p "Choose an option [1-4]: " choice || { echo; echo "Goodbye."; exit 0; }
        case "$choice" in
            1) deploy ;;
            2) run_app ;;
            3) archive_logs ;;
            4) echo "Goodbye."; exit 0 ;;
            *) echo "Invalid choice '$choice'. Please enter 1, 2, 3 or 4." ;;
        esac
    done
}
main
