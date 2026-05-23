from fastapi import Form


class AuthForm:
    """Form body sent by mosquitto-go-auth for connection authentication.

    mosquitto-go-auth POSTs: username=<jwt>&password=&clientid=<clientId>
    """

    def __init__(
        self,
        username: str = Form(...),
        password: str = Form(""),
        clientid: str = Form(""),
    ) -> None:
        self.username = username
        self.password = password
        self.clientid = clientid


class AclForm:
    """Form body sent by mosquitto-go-auth for ACL checks.

    mosquitto-go-auth POSTs:
        username=<jwt>&topic=vena/xyz/telemetry&clientid=<clientId>&acc=1
    acc: 1 = subscribe, 2 = publish, 3 = read (retained), 4 = write (retained)
    """

    def __init__(
        self,
        username: str = Form(...),
        topic: str = Form(...),
        clientid: str = Form(""),
        acc: int = Form(1),
    ) -> None:
        self.username = username
        self.topic = topic
        self.clientid = clientid
        self.acc = acc
