# 防盜黑盒子

## 硬體端

可以在開機的時候自動開啟程序，並在某個事件後自動關閉。

### LSM9DS0

#### Accelerometer
他有偵測物體傾斜程度的功能，細節不知道，但應該是測量重力加速度所算出。

## 通訊

### 通訊媒介 firebase -> mqtt
- 使用免費的網路 server
[HIVEMQ free mqtt server](https://www.hivemq.com/mqtt/public-mqtt-broker/)

### 連線確認

#### client app 
app must connect to black box instead of mqtt server 
- 借鑑TCP的 Three-way handshack

#### black box
box must connect to server

### 通訊訊息格式

#### Header
- 0: come from 板子
- 1: come from app

#### command
- a: ack
    - ai: for inital connection
        - 0ail: for lock state
        - 0aiu: for unlock state
        只有在 box 傳給我時會有這個 field，直接傳上鎖狀態
    - am: for acknowledge message
- s: syn
- f: fin，告知準備斷線
- c: for connection checking
- l: for change lock type
    - 0l: for success change lock type
        - 0lu: unlock
        - oll: lock
- d: detect, 發生事件
    - 0ds: for detect event happened
    - 1d: for disable detect
    - 0da: for ack diable detect

### 解除警戒
- 重新設置 box 那邊的 init_accel_(x,y,z), init_gryo_(x,y,z)

## app 通知
- 如果黑箱被移動
- 如果黑箱離線

## 板子開機時啟動腳本

### 原本借鑑 Lab8 開機服務
在 crontab 裡面新增
@reboot /home/pi/c9sdk/workspace/script/guard_box.sh

### Finally, I use .service to done this

add a new file in /etc/systemd/system

```console
sudo vim /etc/systemd/system/guard_box.service
```

file content

``` console
[Unit]
Description = Guard box
After = network.target

[Service]
ExecStart = /home/pi/c9sdk/workspace/Final/guard_black_box.py
Restart = always

[Install]
WantedBy = multi-user.target
```

because this is system execute, so no need to use `sudo`

update config : `sudo systemctl daemon-reload`
enable service : `sudo systemctl enable guard_box.service`
disable service : `sudo systemctl disable guard_box.service`
start service : `sudo systemctl start guard_box.service`
stop service : `sudo systemctl stop guard_box.service`

# 開發工具

## cloud9

```console
sudo forever /home/pi/c9sdk/server.js -p 8080 -l 0.0.0.0 -a name:passwd -w workspace
```

sometimes it will not execute, maybe it's becuase it cannot find workspace, you should go to right place to execute this command
