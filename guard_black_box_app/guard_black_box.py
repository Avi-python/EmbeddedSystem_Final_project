import time
import datetime
import threading

import board
import busio
import RPi.GPIO as GPIO

import paho.mqtt.client as mqtt

import adafruit_lsm9ds0

GPIO.setmode(GPIO.BCM)
GPIO.setup(17, GPIO.OUT)
pwm = GPIO.PWM(17, 50)
pwm.start(10)
time.sleep(1)

# I2C connection:
i2c = busio.I2C(board.SCL, board.SDA)
sensor = adafruit_lsm9ds0.LSM9DS0_I2C(i2c)

init_accel_x, init_accel_y, init_accel_z = sensor.acceleration
init_gyro_x, init_gyro_y, init_gyro_z = sensor.gyro

topic = "guard_black_box/test1"
isConnected = False
isConnectToServer = False
isLock = False

is_disable_send = False
disable_thread = None

def change_lock_state(lock):
    global isLock
    try:
        if(not lock):
            pwm.ChangeDutyCycle(10)
            time.sleep(1)
            isLock = False
        else:
            pwm.ChangeDutyCycle(5)
            time.sleep(1)
            isLock = True
    except Exception as e:
        print("changeLockStateError: " + str(e))

def on_connect(client, userdata, flags, rc):
    global topic
    print("Connected with result code "+str(rc))
    # Subscribe to the topic when connected
    client.subscribe(topic)
    
def reset_lsm9_baseline():
    global init_accel_x, init_accel_y, init_accel_z
    global init_gyro_x, init_gyro_y, init_gyro_z
    init_accel_x, init_accel_y, init_accel_z = sensor.acceleration
    init_gyro_x, init_gyro_y, init_gyro_z = sensor.gyro

def on_message(client, userdata, msg):
    global isConnected
    global isConnectToServer
    global isLock
    print(f"Received message on topic {msg.topic}: {msg.payload.decode()}")
    msg = msg.payload.decode()
    if(msg[0] == '1'):
        if(msg[1] == 's'):
            if(isLock):
                send_message("0ai" + "l") # 傳送上鎖狀態
            else:
                send_message("0ai" + "u")
        elif(msg[1] == 'a'):
            if(msg[2] == 'i'):
                isConnected = True
                print("well connected")
        elif(msg[1] == 'f'):
            print("app disconnect")
        elif(msg[1] == 'l'):
            change_lock_state(not isLock)
            if(isLock):
                send_message("0l" + "l") # 傳送上鎖狀態
            else:
                send_message("0l" + "u")
            print('change lock state')
        elif(msg[1] == 'd'): # 1d for disabe detect
            reset_lsm9_baseline()
            print("reset_detect_baseline")
            send_message("0da")
        else:
            send_message("0am")
    elif(msg[0] == '0'):
        if(msg[1] == 'c'):
            isConnectToServer = True
        

def send_message(msg):
    try:
        client.publish(topic, msg)
    except Exception as e:
        print("publish message error: " + str(e))

def disable_send_callback():
    global is_disable_send
    cnt = 3
    while(cnt >= 0):
        cnt -= 1;
        time.sleep(1)
    is_disable_send = False


def start_detect():
    global is_disable_send
    global disable_thread
    while True:
        try:
            # Read acceleration, magnetometer, gyroscope, temperature.
            accel_x, accel_y, accel_z = sensor.acceleration
            # mag_x, mag_y, mag_z = sensor.magnetic
            gyro_x, gyro_y, gyro_z = sensor.gyro
            # temp = sensor.temperature
            # Print values.
            result_accel_x = accel_x - init_accel_x
            result_accel_y = accel_y - init_accel_y
            result_accel_z = accel_z - init_accel_z
            
            result_gyro_x = gyro_x - init_gyro_x
            result_gyro_y = gyro_y - init_gyro_y
            result_gyro_z = gyro_z - init_gyro_z
        
            
            if(abs(result_accel_x) > 5 or abs(result_accel_y) > 5 or abs(result_accel_z) > 5 or 
                abs(result_gyro_x) > 80 or abs(result_gyro_y) > 80 or abs(result_gyro_z) > 80):
                if(not is_disable_send):
                    send_message("0ds")
                    print("Trigger_Gyro: " + str(datetime.datetime.now()))
                    is_disable_send = True
                    disable_thread = threading.Thread(target = disable_send_callback)
                    disable_thread.start()
                    change_lock_state(True)
          
            time.sleep(0.1)
            
        except Exception as e:
            # Disconnect from the broker when the script is interrupted
            print("Detect Error: " + str(e))


def server_connection_polling():
    global isConnectToServer
    while(isConnectToServer):
        time.sleep(5) # need to wait a second because loop_start will not block, and it will need a moment to start
        send_message("0c")
        isConnectToServer = False
        time.sleep(5)
    client.disconnect()
    client.loop_stop()
    recover_connection()
    print("server_polling_over")
    
# Connect to the MQTT brokee
def recover_connection():
    global isConnectToServer
    while (not isConnectToServer):
        try:
            client.connect("broker.hivemq.com", 1883, 60)
            client.loop_start() # Start the loop to process messages
            isConnectToServer = True
            t = threading.Thread(target=server_connection_polling)
            t.start()
        except Exception as e:
            print("Recover Connetion fail one: " + str(e))
    print("recover_over")

# Create an MQTT client instance
client = mqtt.Client()

# Set callback functions
client.on_connect = on_connect
client.on_message = on_message

init_accel_x, init_accel_y, init_accel_z = sensor.acceleration
init_gyro_x, init_gyro_y, init_gyro_z = sensor.gyro

recover_connection()
start_detect()

    

