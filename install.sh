#! /bin/bash
targetFiles=('showPlayerIP' 'spi.so')
targetPaths=('/usr/local/bin/' '/usr/local/bin/')
configFile='/usr/local/bin/.showPlayerIP.conf'
serviceShellFile='/etc/init.d/showPlayerIP'
serviceLinkFile='/etc/rc3.d/S88showPlayerIP'
bootShellFile='/etc/rc.local'
syslogConfigFile='/etc/rsyslog.conf'

function showHelp()
{
    echo "for install: ${0} --install"
    echo "for uninstall: ${0} --uninstall"
    echo "for modify key and port: ${0} --modify"
    echo "for help: ${0}"
}

#检测服务文件是否存在，若存在接着检测是否正在运行。
#返回1 表示不存在，或者存在但没运行。
#返回0 表示正在运行
function testServiceRun()
{
    local fn=${targetPaths[0]}${targetFiles[0]}    
    if test -e $fn
    then
        ps -x | grep ${targetFiles[0]} | grep -v "grep" > /dev/null
        return $?
    else
        return 1
    fi
}

function inputKeyAndPort()
{
    while true
    do
        read -p "Enter the key that it gets from software provider(it's length = 8):" key
        if [[ $key =~ ^[a-zA-Z0-9]{8}$ ]]
        then
            break
        else
            echo "the key is incorrect, please retry"
        fi
    done

    while true
    do
        read -p "Enter the port that it gets from software provider(0~65535):" port
        if [[ $port =~ ^[1-9][0-9]{0,4}$ ]]
        then            
            if [ $port -le 65535 ]
            then
                break
            else
                echo "the port > 65535, please retry"
            fi
        else
            echo "the port isn't numeric, please retry"
        fi
    done

    echo -e "$key\n$port\n" > $configFile
}

function install()
{
    #检查下载文件的完整性
    echo -n "(8-1)Check self wholeness..."
    md5sum -c all.md5 --status    
    if [ $? -eq 1 ]
    then
        echo "[FAIL]"
        exit -1
    fi
    echo "[OK]"

    #检查服务是否正在运行
    echo -n "(8-2)Is showPlayerIP service running?..."
    testServiceRun
    if [ $? -eq 0 ]
    then
        echo -e "[FAIL]\nPlease stop it first."
        exit -2    
    fi
    echo "[OK]"
    
    #把服务文件和hook文件复制到指定的目录
    echo -n "(8-3)Copy service and hook file..."
    cp -f ./${targetFiles[0]} ${targetPaths[0]}${targetFiles[0]}
    chmod +x ${targetPaths[0]}${targetFiles[0]}
    cp -f ./${targetFiles[1]} ${targetPaths[1]}${targetFiles[1]}
    echo "[OK]"

    #建立服务的shell文件
    echo -n "(8-4)Create service shell file..."
    echo -e "#! /bin/bash\n### BEGIN INIT INFO\n### this file must be into /etc/init.d/\n#N=/usr/local/bin/showPlayerIP\nset -e\ncase \"\$1\" in\nstart)\n    # make sure privileges don't persist across reboots\n    /usr/local/bin/showPlayerIP &\n    ;;\nstop)\n    pkill showPlayerIP\n    ;;\nrestart)\n    pkill showPlayerIP\n    /usr/local/bin/showPlayerIP &\n    ;;\nesac\nexit 0\n" > $serviceShellFile
    chmod +x $serviceShellFile
    echo "[OK]"
    
    #建立服务shell文件的快捷方式
    echo -n "(8-5)Create service shell link file..."
    ln -sf $serviceShellFile $serviceLinkFile
    echo "[OK]"

    #输入密钥与端口号并保存    
    inputKeyAndPort
    echo "(8-6)Save key and port...[OK]"

    #设置为随机启动
    echo -n "(8-7)Set launch service with boot..."
    cmd='service showPlayerIP start'
    cat $bootShellFile | grep "$cmd" > /dev/null
    if [ $? -eq 1 ]
    then
        echo -e "\n$cmd\n" >> $bootShellFile
    fi
    echo "[OK]"

    #设置日志文件，以便显示日志
    echo -n "(8-8)Set syslog config ..."
    flag="local3.*"
    cmd='local3.*                                                /var/log/showPlayerIPService.log'
    cat $syslogConfigFile | grep "$flag" > /dev/null
    if [ $? -eq 1 ]
    then
        echo -e "\n$cmd\n" >> $syslogConfigFile
    fi
    #修改日志的配置文件后，必须要重启，才能生效
    systemctl restart rsyslog
    echo "[OK]"

    service ${targetFiles[0]} start
}

function uninstall()
{    
    echo -n "(7-1)Is showPlayerIP service running?..."
    testServiceRun
    if [ $? -eq 0 ]
    then
        echo -e "[fail]\nPlease stop it first."
        exit -2    
    fi
    echo "[OK]"

    echo -n "(7-2)Delete service file..."
    rm -f ${targetPaths[0]}${targetFiles[0]}
    if [ $? -eq 0 ]; then
        echo "[OK]"
    else
        echo "[FAIL]"
        exit -1
    fi

    echo -n "(7-3)Delete hook file..."    
    rm -f ${targetPaths[1]}${targetFiles[1]}
    if [ $? -eq 0 ]; then
        echo "[OK]"
    else
        echo "[FAIL]"
        exit -2
    fi

    echo -n "(7-4)Delete config file..."
    rm -f $configFile
    if [ $? -eq 0 ]; then
        echo "[OK]"
    else
        echo "[FAIL]"
        exit -3
    fi

    echo -n "(7-5)Delete service shell file..."
    rm -f $serviceShellFile
    if [ $? -eq 0 ]; then
        echo "[OK]"
    else
        echo "[FAIL]"
        exit -4
    fi

    echo -n "(7-6)Delete service shell link file..."
    rm -f $serviceLinkFile
    if [ $? -eq 0 ]; then
        echo "[OK]"
    else
        echo "[FAIL]"
        exit -5
    fi

    echo -n "(7-7)Delete from boot script..."
    sed -i '/service showPlayerIP start/d' /etc/rc.local
    if [ $? -eq 0 ]; then
        echo "[OK]"
    else
        echo "[FAIL]"
        exit -6
    fi

    echo "Uninstall successed!"
}

#The main program, start here!
echo "Welcome to Show_Player_Real_IP ©SuperTech Hangzhou install program!"

case $# in    
    1)
        if [ $1 == "--install" ]; then
            install
            echo "Install successed!"
        elif [ $1 == "--uninstall" ]; then
            uninstall
        elif [ $1 == "--modify" ]; then
            inputKeyAndPort
            echo "Modify successed!"
        else
            showHelp
        fi        
        ;;
    *)        
        showHelp
esac