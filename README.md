# 防盜黑盒子

## LS9DS0

### Accelerometer
他有偵測物體傾斜程度的功能，細節不知道，但應該是測量重力加速度所算出。

### 通訊媒介 firebase -> mqtt
- 使用免費的網路 server

### 連線確認
- 借鑑TCP的 Three-way handshack

### 通訊訊息格式

#### Header
- 0: come from 板子
- 1: come from app

#### command
- a: ack
    - ai: for inital connection
    - am: for acknowledge message
    - ad: for disconnect
- s: syn
- f: fin，告知準備斷線
