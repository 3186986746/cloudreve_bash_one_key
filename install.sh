#!/bin/bash

Green_font_prefix="\033[32m"
Red_font_prefix="\033[31m"
Green_background_prefix="\033[42;37m"
Red_background_prefix="\033[41;37m"
Font_color_suffix="\033[0m"
Info="[${Green_font_prefix}Infor${Font_color_suffix}]"
Error="[${Red_font_prefix}Error${Font_color_suffix}]"
Tip="[${Green_font_prefix}Notice${Font_color_suffix}]"

#fonts color
Green="\033[32m"
Red="\033[31m"
# Yellow="\033[33m"
GreenBG="\033[42;37m"
RedBG="\033[41;37m"
Font="\033[0m"

#notification information
# Info="${Green}[信息]${Font}"
OK="${Green}[OK]${Font}"
Error="${Red}[Error]${Font}"

shell_conf_dir="$HOME/.config/kami233boy/"

check_if_running_as_root() {
    # If you want to run as another user, please modify $UID to be owned by this user
    if [[ "$UID" -ne '0' ]]; then
        echo "error: You must run this script as root!"
        exit 1
    fi
}

identify_the_operating_system_and_architecture() {
    if [[ "$(uname)" == 'Linux' ]]; then
        case "$(uname -m)" in
            'i386' | 'i686')
                MACHINE='32'
                ;;
            'amd64' | 'x86_64')
                MACHINE='64'
                ;;
            'armv5tel')
                MACHINE='arm32-v5'
                ;;
            'armv6l')
                MACHINE='arm32-v6'
                ;;
            'armv7' | 'armv7l' )
                MACHINE='arm32-v7a'
                ;;
            'armv8' | 'aarch64')
                MACHINE='arm64-v8a'
                ;;
            'mips')
                MACHINE='mips32'
                ;;
            'mipsle')
                MACHINE='mips32le'
                ;;
            'mips64')
                MACHINE='mips64'
                ;;
            'mips64le')
                MACHINE='mips64le'
                ;;
            'ppc64')
                MACHINE='ppc64'
                ;;
            'ppc64le')
                MACHINE='ppc64le'
                ;;
            'riscv64')
                MACHINE='riscv64'
                ;;
            *)
                echo "error: The architecture is not supported."
                exit 1
                ;;
        esac
        if [[ ! -f '/etc/os-release' ]]; then
            echo "error: Don't use outdated Linux distributions."
            exit 1
        fi
        if [[ -z "$(ls -l /sbin/init | grep systemd)" ]]; then
            echo "error: Only Linux distributions using systemd are supported."
            exit 1
        fi
        if [[ "$(command -v apt)" ]]; then
            PACKAGE_MANAGEMENT_INSTALL='apt install'
            PACKAGE_MANAGEMENT_REMOVE='apt remove'
        elif [[ "$(command -v yum)" ]]; then
            PACKAGE_MANAGEMENT_INSTALL='yum install'
            PACKAGE_MANAGEMENT_REMOVE='yum remove'
            if [[ "$(command -v dnf)" ]]; then
                PACKAGE_MANAGEMENT_INSTALL='dnf install'
                PACKAGE_MANAGEMENT_REMOVE='dnf remove'
            fi
        elif [[ "$(command -v zypper)" ]]; then
            PACKAGE_MANAGEMENT_INSTALL='zypper install'
            PACKAGE_MANAGEMENT_REMOVE='zypper remove'
        else
            echo "error: The script does not support the package manager in this operating system."
            exit 1
        fi
    else
        echo "error: This operating system is not supported."
        exit 1
    fi
}

judgment_parameters() {
    if [[ "$#" -gt '0' ]]; then  # 如果脚本参数大于0
        case "$1" in
            '--remove')
                if [[ "$#" -gt '1' ]]; then
                    echo 'error: Please enter the correct parameters.'
                    exit 1
                fi
                REMOVE='1'
                ;;
            '--version')
                if [[ "$#" -gt '2' ]] || [[ -z "$2" ]]; then
                    echo 'error: Please specify the correct version.'
                    exit 1
                fi
                VERSION="$2"
                ;;
            '-c' | '--check')
                if [[ "$#" -gt '1' ]]; then
                    echo 'error: Please enter the correct parameters.'
                    exit 1
                fi
                CHECK='1'
                ;;
            '-f' | '--force')
                if [[ "$#" -gt '1' ]]; then
                    echo 'error: Please enter the correct parameters.'
                    exit 1
                fi
                FORCE='1'
                ;;
            '-h' | '--help')
                if [[ "$#" -gt '1' ]]; then
                    echo 'error: Please enter the correct parameters.'
                    exit 1
                fi
                HELP='1'
                ;;
            '-l' | '--local')
                if [[ "$#" -gt '2' ]] || [[ -z "$2" ]]; then
                    echo 'error: Please specify the correct local file.'
                    exit 1
                fi
                LOCAL_FILE="$2"
                LOCAL_INSTALL='1'
                ;;
            '-p' | '--proxy')
                case "$2" in
                    'http://'*)
                        ;;
                    'https://'*)
                        ;;
                    'socks4://'*)
                        ;;
                    'socks4a://'*)
                        ;;
                    'socks5://'*)
                        ;;
                    'socks5h://'*)
                        ;;
                    *)
                        echo 'error: Please specify the correct proxy server address.'
                        exit 1
                        ;;
                esac
                PROXY="-x$2"
                # Parameters available through a proxy server
                if [[ "$#" -gt '2' ]]; then
                    case "$3" in
                        '--version')
                            if [[ "$#" -gt '4' ]] || [[ -z "$4" ]]; then
                                echo 'error: Please specify the correct version.'
                                exit 1
                            fi
                            VERSION="$2"
                            ;;
                        '-c' | '--check')
                            if [[ "$#" -gt '3' ]]; then
                                echo 'error: Please enter the correct parameters.'
                                exit 1
                            fi
                            CHECK='1'
                            ;;
                        '-f' | '--force')
                            if [[ "$#" -gt '3' ]]; then
                                echo 'error: Please enter the correct parameters.'
                                exit 1
                            fi
                            FORCE='1'
                            ;;
                        *)
                            echo "$0: unknown option -- -"
                            exit 1
                            ;;
                    esac
                fi
                ;;
            *)
                echo "$0: unknown option -- -"
                exit 1
                ;;
        esac
    fi
}

decompression() {
    if ! tar -zxvf "$1" -C "$TMP_DIRECTORY"; then
        echo 'error: Cloudreve decompression failed.'
        rm -r "$TMP_DIRECTORY"
        echo "removed: $TMP_DIRECTORY"
        exit 1
    fi
    echo "info: Extract the Cloudreve package to $TMP_DIRECTORY and prepare it for installation."
}

install_software() {
    COMPONENT="$1"
    if [[ -n "$(command -v "$COMPONENT")" ]]; then
        return
    fi
    ${PACKAGE_MANAGEMENT_INSTALL} "$COMPONENT"
    if [[ "$?" -ne '0' ]]; then
        echo "error: Installation of $COMPONENT failed, please check your network."
        exit 1
    fi
    echo "info: $COMPONENT is installed."
}

get_version() {
    # 0: Install or update Cloudreve.
    # 1: Installed or no new version of Cloudreve.
    # 2: Install the specified version of Cloudreve.
    if [[ -z "$VERSION" ]]; then
        # Determine the version number for Cloudreve installed from a local file
        if [[ -f "${shell_conf_dir}shconf.conf" ]]; then
            CURRENT_VERSION="$(sed -n '/^version/p' "${shell_conf_dir}shconf.conf" | awk -F '=' '{print $2}')"
            
        fi
        # Get Cloudreve release version number
        RELEASE_VERSION="$(curl -s https://api.github.com/repos/cloudreve/Cloudreve/releases/latest | sed 'y/,/\n/' | grep 'tag_name' | awk -F '"' '{print $4}')"
        echo $RELEASE_VERSION
        echo $CURRENT_VERSION
        # Compare Cloudreve version numbers
        # Compare Cloudreve version numbers
        if [[ "$RELEASE_VERSION" != "$CURRENT_VERSION" ]]; then
            RELEASE_VERSIONSION_NUMBER="${RELEASE_VERSION}"
            RELEASE_MAJOR_VERSION_NUMBER="${RELEASE_VERSIONSION_NUMBER%%.*}"
            RELEASE_MINOR_VERSION_NUMBER="$(echo "$RELEASE_VERSIONSION_NUMBER" | awk -F '.' '{print $2}')"
            RELEASE_MINIMUM_VERSION_NUMBER="${RELEASE_VERSIONSION_NUMBER##*.}"
            CURRENT_VERSIONSION_NUMBER="$(echo "${CURRENT_VERSION}" | sed 's/-.*//')"
            CURRENT_MAJOR_VERSION_NUMBER="${CURRENT_VERSIONSION_NUMBER%%.*}"
            CURRENT_MINOR_VERSION_NUMBER="$(echo "$CURRENT_VERSIONSION_NUMBER" | awk -F '.' '{print $2}')"
            CURRENT_MINIMUM_VERSION_NUMBER="${CURRENT_VERSIONSION_NUMBER##*.}"
            if [[ "$RELEASE_MAJOR_VERSION_NUMBER" -gt "$CURRENT_MAJOR_VERSION_NUMBER" ]]; then
		echo "-gt"
                return 0
            elif [[ "$RELEASE_MAJOR_VERSION_NUMBER" -eq "$CURRENT_MAJOR_VERSION_NUMBER" ]]; then
                if [[ "$RELEASE_MINOR_VERSION_NUMBER" -gt "$CURRENT_MINOR_VERSION_NUMBER" ]]; then
                    echo "-eq-gt"
                    return 0
                elif [[ "$RELEASE_MINOR_VERSION_NUMBER" -eq "$CURRENT_MINOR_VERSION_NUMBER" ]]; then
                    if [[ "$RELEASE_MINIMUM_VERSION_NUMBER" -gt "$CURRENT_MINIMUM_VERSION_NUMBER" ]]; then
			echo "-eq-eq-gt"
                        return 0
                    else
                        return 1
                    fi
                else
                    return 1
                fi
            else
                return 1
            fi
        elif [[ "$RELEASE_VERSION" == "$CURRENT_VERSION" ]]; then
            return 1
        fi

    else
        RELEASE_VERSION="$(version_number "$VERSION")"
        return 2
    fi
}

download_cloudreve() {
    mkdir "$TMP_DIRECTORY"
    DOWNLOAD_LINK="$(curl -s https://api.github.com/repos/cloudreve/Cloudreve/releases/latest | grep "browser_download_url.*linux_amd64.tar.gz" | cut -d : -f 2,3 | tr -d \")"
    DOWNLOAD_LINK="$(echo $DOWNLOAD_LINK | awk '$1=$1')"
    DOWNLOAD_LINK="https://www.xvfex.com.cn/api/v3/file/source/2255/cloudreve_3.5.3_linux_amd64.tar.gz?sign=jGbr5jHUaBE5lqxWye9GYkhRw4zjGNZwgbjt0AYvIHE%3D%3A0"
    echo "Downloading Cloudreve archive: $DOWNLOAD_LINK"
    if ! curl -L -H 'Cache-Control: no-cache' -o "$ZIP_FILE" "$DOWNLOAD_LINK"; then
        echo 'error: Download failed! Please check your network or try again.'
        return 1
    fi
}

install_file() {
    NAME="$1"
    if [[ "$NAME" == 'cloudreve' ]]; then
        install -m 755 "${TMP_DIRECTORY}$NAME" "${HOMEDIR}$NAME"
	sed -i "s/^\(version=\).*/\1${RELEASE_VERSION}/g" "${shell_conf_dir}shconf.conf"
    fi
}

install_cloudreve() {
    # Install Cloudreve binary to /usr/local/bin/ and $DAT_PATH
    install_file cloudreve
    echo "cloudreve installed to ${HOMEDIR}"
}

install_startup_service_file() {
    if [[ ! -f '/etc/systemd/system/cloudreve.service' ]]; then
        mkdir -p "${TMP_DIRECTORY}systemd/system/"
        install_software curl
        cat > "${TMP_DIRECTORY}systemd/system/cloudreve.service" <<-EOF
[Unit]
Description=Cloudreve Service
After=network.target nss-lookup.target

[Service]
User=root
ExecStartPre=-/bin/sleep 5s
WorkingDirectory=${HOMEDIR}
StandardOutput=file:${HOMEDIR}log.log
StandardError=file:${HOMEDIR}log.log
ExecStart=${HOMEDIR}cloudreve
Restart=on-abnormal
RestartSec=5s
KillMode=mixed

[Install]
WantedBy=multi-user.target
EOF
        install -m 644 "${TMP_DIRECTORY}systemd/system/cloudreve.service" /etc/systemd/system/cloudreve.service
        SYSTEMD='1'
    fi
    systemctl daemon-reload
}

start_cloudreve() {
    if [[ -f '/etc/systemd/system/cloudreve.service' ]]; then
        if [[ -z "$CLOUDREVE_CUSTOMIZE" ]]; then
            systemctl start cloudreve
        else
            systemctl start "$CLOUDREVE_CUSTOMIZE"
        fi
    fi
    if [[ "$?" -ne 0 ]]; then
        echo 'error: Failed to start Cloudreve service.'
        exit 1
    fi
    echo 'info: Start the Cloudreve service.'

}

stop_cloudreve() {
    CLOUDREVE_CUSTOMIZE="$(systemctl list-units | grep 'cloudreve@' | awk -F ' ' '{print $1}')"
    if [[ -z "$CLOUDREVE_CUSTOMIZE" ]]; then
        systemctl stop cloudreve
    else
        systemctl stop "$CLOUDREVE_CUSTOMIZE"
    fi
    if [[ "$?" -ne '0' ]]; then
        echo 'error: Stopping the Cloudreve service failed.'
        exit 1
    fi
    echo 'info: Stop the Cloudreve service.'
}

cloudreve_install() {

     # Two very important variables
    TMP_DIRECTORY="$(mktemp -du)/"
    DOWNURL="$(curl -s https://api.github.com/repos/cloudreve/Cloudreve/releases/latest | grep "browser_download_url.*linux_amd64.tar.gz" | cut -d : -f 2,3 | tr -d \")"
    ZIP_FILE="${TMP_DIRECTORY}${DOWNURL##*/}"
    
    # Parameter information
    [[ "$HELP" -eq '1' ]] && show_help
    [[ "$CHECK" -eq '1' ]] && check_update
    [[ "$REMOVE" -eq '1' ]] && remove_cloudreve

    # whether has been installed
    if [[ -f ${shell_conf_dir}shconf.conf ]]; then
        HOMEDIR="$(sed -n "/homedir/p" "${shell_conf_dir}shconf.conf"  | awk -F '=' '{print $2}')"
	echo -e "Cloudreve has been installed to ${HOMEDIR} with this script."
	read -rp "Enter a number (0|install anyway  1|exit):" INSTALL_EXIT
	case ${INSTALL_EXIT} in
		1)
			exit
			;;
		*)
			;;
	esac

    fi
    
    # installation directory
    read -r -p "Enter the installation directory (default: "$(pwd)"):" HOMEDIR
    [[ -z ${HOMEDIR} ]] && HOMEDIR="$(pwd)/"
    [[ ! -d ${HOMEDIR} ]] && echo "Not a directory. exiting~~~"  && exit
    [[ ${HOMEDIR} != */ ]] && HOMEDIR="${HOMEDIR}/"
    
    # shell conf file
    mkdir -p "${TMP_DIRECTORY}.config/kami233boy"
    cat > "${TMP_DIRECTORY}.config/kami233boy/shconf.conf" <<-EOF
version=
admin=
password=
homedir=${HOMEDIR}
EOF
    
    [[ -f ${shell_conf_dir}shconf.conf ]] && rm -f ${shell_conf_dir}shconf.conf
    mkdir -p ${shell_conf_dir}
    install -m 644 "${TMP_DIRECTORY}.config/kami233boy/shconf.conf" "${shell_conf_dir}shconf.conf"
    
    # get update
    get_version
    NUMBER="$?"
    # echo "get_version returned ${NUMBER}"
    if [[ "$NUMBER" -eq '0' ]]; then
	    echo "info: Installing Cloudreve $RELEASE_VERSION for $(uname -m)"
	    download_cloudreve
	    if [[ "$?" -eq '1' ]]; then
		    rm -r "$TMP_DIRECTORY"
		    echo "removed: $TMP_DIRECTORY"
		    exit 0
	    fi
	    install_software tar
	    decompression "$ZIP_FILE"
	elif [[ "$NUMBER" -eq '1' ]]; then
		echo "info: No new version. The current version of Cloudreve is $CURRENT_VERSION ."
		exit 0
	fi

    # Determine if Cloudreve is running
    if [[ -n "$(systemctl list-unit-files | grep 'cloudreve')" ]]; then
	    if [[ -n "$(pidof cloudreve)" ]]; then
	    echo "cloudre is running"
            stop_cloudreve
            CLOUDREVE_RUNNING='1'
        fi
    fi
    install_cloudreve
    install_startup_service_file
    echo "installed ${HOMEDIR}" 
    if [[ "$SYSTEMD" -eq '1' ]]; then
        echo 'installed: /etc/systemd/system/cloudreve.service'
    fi
    rm -r "$TMP_DIRECTORY"
    echo "removed: $TMP_DIRECTORY"
    if [[ "$LOCAL_INSTALL" -eq '1' ]]; then
        get_version
    fi
    echo "info: Cloudreve $RELEASE_VERSION is installed."
    echo "You may need to execute a command to remove dependent software: $PACKAGE_MANAGEMENT_REMOVE curl tar"
    if [[ "$CLOUDREVE_RUNNING" -eq '1' ]]; then
        start_cloudreve
    else
	start_cloudreve
        echo 'Please execute the command: systemctl enable cloudreve; systemctl start cloudreve'
    fi
    while [[ -z "$(sed -n "/开始监听/p" "${HOMEDIR}log.log")" ]]; do
        sleep 1
    done
    if [[ ! -z "$(sed -n "/初始管理员账号/p" "${HOMEDIR}log.log")" ]]; then
        echo tongguo
        USERNAME="$(sed -n "/初始管理员账号/p" "${HOMEDIR}log.log")"
        echo ${USERNAME##*：}
        PASSWORD="$(sed -n "/初始管理员密码/p" "${HOMEDIR}log.log")"
        echo ${PASSWORD##*：}
        sed -i "s/^\(admin=\).*/\1${USERNAME##*：}/g" "${shell_conf_dir}shconf.conf"
        sed -i "s/^\(password=\).*/\1${PASSWORD##*：}/g" "${shell_conf_dir}shconf.conf"

    fi

}







uninstall_all() {
    HOMEDIR="$(sed -n "/homedir/p" "${shell_conf_dir}shconf.conf"  | awk -F '=' '{print $2}')" || exit
    [[ -z $HOMEDIR ]] && echo Cloudreve has not been installed with this script. && exit

    stop_process_systemd
    [[ -f "/etc/systemd/system/cloudreve.service" ]] && rm -f /etc/systemd/system/cloudreve.service
    INSTALLDIR="$(sed -n "/homedir/p" "${shell_conf_dir}shconf.conf"  | awk -F '=' '{print $2}')" || exit
    [[ -d $INSTALLDIR ]] && rm -f ${INSTALLDIR}cloudreve && rm -f ${INSTALLDIR}cloudreve.db && rm -f ${INSTALLDIR}conf.ini && rm -rf ${INSTALLDIR}uploads && rm -f ${INSTALLDIR}log.log
    [[ -d ${shell_conf_dir} ]] && rm -rf ${shell_conf_dir}
    systemctl daemon-reload
    echo -e "${OK} ${GreenBG} Uninstalled ${Font}"
}

modify_cloudreve_port() {
    HOMEDIR="$(sed -n "/homedir/p" "${shell_conf_dir}shconf.conf"  | awk -F '=' '{print $2}')" || exit
    [[ -z $HOMEDIR ]] && echo Cloudreve has not been installed with this script. && exit

    INSTALLDIR="$(sed -n "/homedir/p" "${shell_conf_dir}shconf.conf"  | awk -F '=' '{print $2}')" || exit
    sed -i "s/^\(Listen = :\).*/\1${port}/g" "${INSTALLDIR}conf.ini"
    judge "Alter port"
}

show_information() {
    HOMEDIR="$(sed -n "/homedir/p" "${shell_conf_dir}shconf.conf"  | awk -F '=' '{print $2}')" || exit
    [[ -z $HOMEDIR ]] && echo Cloudreve has not been installed with this script. && exit

    cat "${shell_conf_dir}shconf.conf"
}

judge() {
    if [[ 0 -eq $? ]]; then
        echo -e "${OK} ${GreenBG} $1 Finished ${Font}"
        sleep 1
    else
        echo -e "${Error} ${RedBG} $1 Failed ${Font}"
        exit 1
    fi
}

start_process_systemd() {
    systemctl daemon-reload
    systemctl restart cloudreve
    judge "Cloudreve Start"
}

enable_process_systemd() {
    systemctl enable cloudreve
    judge "Set cloudreve auto start"
}

stop_process_systemd() {
    systemctl stop cloudreve
}

install_cloudreve_only() {
    judgment_parameters "$@"
    cloudreve_install

    enable_process_systemd
}
update_cloudreve() {

    HOMEDIR="$(sed -n "/homedir/p" "${shell_conf_dir}shconf.conf"  | awk -F '=' '{print $2}')" || exit
    [[ -z $HOMEDIR ]] && echo Cloudreve has not been installed with this script. && exit

    # Two very important variables
    TMP_DIRECTORY="$(mktemp -du)/"
    DOWNURL="$(curl -s https://api.github.com/repos/cloudreve/Cloudreve/releases/latest | grep "browser_download_url.*linux_amd64.tar.gz" | cut -d : -f 2,3 | tr -d \")"
    ZIP_FILE="${TMP_DIRECTORY}${DOWNURL##*/}"

    
    get_version
    NUMBER="$?"
    if [[ "$NUMBER" -eq '0' ]] || [[ "$FORCE" -eq '1' ]] || [[ "$NUMBER" -eq 2 ]]; then
	    echo "info: Installing Cloudreve $RELEASE_VERSION for $(uname -m)"
	    download_cloudreve
	    if [[ "$?" -eq '1' ]]; then
		    rm -r "$TMP_DIRECTORY"
		    echo "removed: $TMP_DIRECTORY"
		    exit 0
	    fi
	    install_software tar
	    decompression "$ZIP_FILE"
	elif [[ "$NUMBER" -eq '1' ]]; then
		echo "info: No new version. The current version of Cloudreve is $CURRENT_VERSION ."
		exit 0
	fi

    # Determine if Cloudreve is running
    if [[ -n "$(systemctl list-unit-files | grep 'cloudreve')" ]]; then
	    if [[ -n "$(pidof cloudreve)" ]]; then
	    echo "cloudre is running"
            stop_cloudreve
            CLOUDREVE_RUNNING='1'
        fi
    fi
    install_cloudreve
    echo "installed ${HOMEDIR}" 
    rm -r "$TMP_DIRECTORY"
    echo "removed: $TMP_DIRECTORY"
    echo "info: Cloudreve $RELEASE_VERSION is installed."
    echo "You may need to execute a command to remove dependent software: $PACKAGE_MANAGEMENT_REMOVE curl tar"
    if [[ "$CLOUDREVE_RUNNING" -eq '1' ]]; then
        start_cloudreve
    else
	start_cloudreve
        echo 'Please execute the command: systemctl enable cloudreve; systemctl start cloudreve'
    fi
    while [[ -z "$(sed -n "/开始监听/p" "${HOMEDIR}log.log")" ]]; do
        sleep 1
    done
    if [[ ! -z "$(sed -n "/初始管理员账号/p" "${HOMEDIR}log.log")" ]]; then
        USERNAME="$(sed -n "/初始管理员账号/p" "${HOMEDIR}log.log")"
        echo ${USERNAME##*：}
        PASSWORD="$(sed -n "/初始管理员密码/p" "${HOMEDIR}log.log")"
        echo ${PASSWORD##*：}
        sed -i "s/^\(admin=\).*/\1${USERNAME##*：}/g" "${shell_conf_dir}shconf.conf"
        sed -i "s/^\(password=\).*/\1${PASSWORD##*：}/g" "${shell_conf_dir}shconf.conf"
    fi
}
menu() {
    echo -e "\t Cloudreve Installation Management Script ${Red}[${shell_version}]${Font}"
    echo -e "\t---authored by kami233boy---"

    echo -e "—————————————— Install Wizard —————————————————"""
    echo -e "${Green}0.${Font}  Update Script"
    echo -e "${Green}1.${Font}  Install Cloudreve"
    echo -e "${Green}2.${Font}  Install Cloudreve + Nginx"
    echo -e "${Green}3.${Font}  Update Cloudreve"
    echo -e "——————————— Change Configuration ——————————————"
    echo -e "${Green}4.${Font}  Alter port"
    echo -e "————————————— Show Information ————————————————"
    echo -e "${Green}5.${Font} Show Cloudreve Configuration"
    echo -e "—————————————————— Others —————————————————————"
    echo -e "${Green}6.${Font} Uninstall Cloudreve and Delete Files"
    echo -e "${Green}7.${Font} Exit \n"

    read -rp "Please enter a number：" menu_num
    case $menu_num in
    0)
        #update_sh
        ;;
    1)
	install_cloudreve_only
        ;;
    2)
        install_v2_h2
        ;;
    3)
        update_cloudreve
        ;;
    4)
        read -rp "Please enter the port:" port
        modify_cloudreve_port
        start_process_systemd
        ;;
    5)
        show_information
        ;;
    6)
        source '/etc/os-release'
        uninstall_all
        ;;
    7)
        exit 0
        ;;
    *)
        echo -e "${RedBG}Please enter the correct number${Font}"
        ;;
    esac
}

list() {
    
    check_if_running_as_root
    identify_the_operating_system_and_architecture
    case $1 in
    *)
        menu
        ;;
    esac
}

list "$1"


