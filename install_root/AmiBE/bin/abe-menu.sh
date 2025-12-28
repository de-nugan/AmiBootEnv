#!/bin/bash

my_name="${0##*/}"
my_path="${0%/${my_name}}"
. "${my_path}/config.sh"

# $1 = Full path to menu list file
# $2 = Timeout in seconds

# Selected menu entry will be stored in $abe_menu_selection
# $abe_key_selection will also be set only when selected by [H]otkey

unset abe_menu_selection
unset abe_key_selection

menu_items_file="${1}"
previous_selection_file="${1}.selection"
touch "${previous_selection_file}"

mapfile -t menu_items < $menu_items_file

menu_length=${#menu_items[@]}

TIMEOUT=${2:-5}
remaining=$TIMEOUT
selected_index=0

# Colours
SELECTION_COLOUR="\033[1;32m"
SELECTION_RESET="\033[0m"

# Terminal size
term_rows=$(tput lines)
term_cols=$(tput cols)

center_line() {
    local text="$1"
    # +1 for rounding up, extra spaces to clear keyboard mashing
    printf "%*s%s    \n" $(( (term_cols - ${#text} + 1) / 2 )) "" "$text"
}

center_line_selected() {
    local text="$1"
    printf "%*s${SELECTION_COLOUR}[ %s ]${SELECTION_RESET}\n" $(( ((term_cols - ${#text} + 1) / 2) - 1 )) "" "$text"
}


right_line() {
    local text="$1"
    printf "%*s%s" $(( (term_cols - ${#text} - 1) )) "" "$text"
}


draw_menu() {
    # Clear causes flicker, so be selective with blanking
    # clear
    tput home

    local menu_height=$((menu_length + 2))
    local start_row=$(( ((term_rows - menu_height) / 2) - 1 ))

    for ((i=0; i<start_row; i++)); do
        # Spaces to clear keyboard mashing
        echo "      "
    done

    # A menu title could go here if we wanted one
    #center_line "AmiBootEnv"
    #echo

    for ((i=0; i<menu_length; i++)); do
        if [[ $i -eq $selected_index ]]; then
            center_line_selected "${menu_items[$i]}"
        else
            center_line "  ${menu_items[$i]}"
        fi
    done

    for ((i=$((start_row + menu_height)) ; i<term_rows; i++)); do
        echo "      "
    done

    right_line "${remaining}"
}

# Set selected pos to last selected
last_selection=$(cat "${previous_selection_file}" 2>/dev/null)

if [[ -n $last_selection ]]; then
    for i in "${!menu_items[@]}"; do
        if [[ "${menu_items[$i]}" == "${last_selection}" ]]; then
            selected_index=$i
            break
        fi
    done
fi

clear

while true; do

    draw_menu

    read -rsn1 -t 1 key

    if [[ $? -eq 0 ]]; then
        remaining=$TIMEOUT
        if [[ $key == $'\x1b' ]]; then
            read -rsn2 key
            case "$key" in
                "[A") ((selected_index--)) ;;
                "[B") ((selected_index++)) ;;
            esac

            ((selected_index < 0)) && selected_index=$((menu_length - 1))
            ((selected_index >= menu_length)) && selected_index=0
        elif [[ $(grep -i "(${key})" "${menu_items_file}") ]]; then
            # abe_key_selection only gets set on explicit key press
            abe_key_selection=$key
            abe_menu_selection=$(grep -i --max-count=1 "(${key})" "${menu_items_file}")
            break
        elif [[ $key == "" ]]; then
            break
        fi
    else
        ((remaining--))
        [[ $remaining -le 0 ]] && break
        #break
    fi
done

clear

if [[ ! $abe_menu_selection ]]; then
    abe_menu_selection="${menu_items[$selected_index]}"
fi

echo "${abe_menu_selection}" > "${previous_selection_file}"

export abe_menu_selection
export abe_key_selection

