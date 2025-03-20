int motor1 = 3;
int motor2 = 5;
int motor3 = 6;
int motor4 = 9;
String input = "";
String yon = "";
int hiz = 0;
int analogPinler[] = {0, 1, 2, 3};
int raw = 0;
int Vin = 5;
float Vout = 0;
float R = 270;
float RDegerler[4] = {0, 0, 0, 0};
float buffer = 0;

void setup() {
    Serial.begin(9600);
    analogWrite(motor1, 0);
    analogWrite(motor2, 0);
    analogWrite(motor3, 0);
    analogWrite(motor4, 0);
}

void loop() {
    delay(100);
    if (Serial.available()) {
        input = Serial.readString();
        yon = input.substring(0, 2);
        hiz = (input.substring(2).toInt()) * 28;

        if (yon == "BT") {
            int motor[] = {3}; 
            motorCalistir(motor, 1, hiz);
            delay(100);
        } else if (yon == "GY") {
            int motor[] = {5}; 
            motorCalistir(motor, 1, hiz);
            delay(100);
        } else if (yon == "DG") {
            int motor[] = {6}; 
            motorCalistir(motor, 1, hiz);
            delay(100);
        } else if (yon == "KY") {
            int motor[] = {9}; 
            motorCalistir(motor, 1, hiz);
            delay(100);
        } else if (yon == "KL") {
            int motor[] = {3, 9}; 
            motorCalistir(motor, 2, hiz);
            delay(100);
        } else if (yon == "PZ") {
            int motor[] = {6, 9}; 
            motorCalistir(motor, 2, hiz);
            delay(100);
        } else if (yon == "LS") {
            int motor[] = {3, 5}; 
            motorCalistir(motor, 2, hiz);
            delay(100);
        }else if (yon == "KE") {
            int motor[] = {5, 6}; 
            motorCalistir(motor, 2, hiz);
            delay(100);
        }
    }
}

void motorCalistir(int motor[], int uzunluk, int hiz) {
    veriGonder();

    for (int i = 0; i <= 500; i++) {
        for(int j = 0; j < uzunluk; j++)
        {
          analogWrite(motor[j], hiz);
        }
        if (i % 50 == 0) {
            veriGonder();
        }
        delay(10);
    }
    
    for(int j = 0; j < uzunluk; j++)
    {
      analogWrite(motor[j], 0);
    }
    Serial.println("END");
}

void veriGonder() {
    String message = "";
    for (int i = 0; i < 4; i++) {
        raw = analogRead(analogPinler[i]);
        if (raw) {
            buffer = raw * Vin;
            Vout = (buffer) / 1024.0;
            buffer = (Vin / Vout) - 1;
            RDegerler[i] = R * buffer;
            message = message + "R" + String(i+1) + ": " + String(RDegerler[i]) + ", ";
        }
    }
    Serial.println(message.substring(0, message.length() - 2));
}
