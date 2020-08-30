function Exchange(ready) {
	self = this;
	var callbacks = {};
	var socket = 0;
	if ( socket != 0 ) {
		socket.close()
	}
	//socket = new WebSocket("ws://"+document.location.hostname+":3333/websocket");
	socket = new WebSocket("wss://"+document.location.host+"/storm/websocket");

	socket.onopen = function() {
		//p("Connected<br>")
		ready(self);				
	};

	socket.onclose = function(event) {
		if (event.wasClean) {
			//p('Соединение закрыто чисто<br>');
		} else {
			//p('Обрыв соединения<br>');
		}
		//p('Код: ' + event.code + ' причина: ' + event.reason +'<br>');
	};

	socket.onmessage = function(event) {
		try {
			data = JSON.parse(event.data)
			if ( data['action'] == 'event' ) {
				exchange = data['name']
				callbacks[exchange](data)
			}
		} catch (e) {}
		return;
	};
	
	self.subscribe = function(exchange,callback) {
		var z = { 'action' : 'subscribe', 'name' : exchange }
		var x = JSON.stringify(z)
		socket.send(x)
		callbacks[exchange] = callback;
	}

	self.publishEvent = function(exchange,msg) {
		var z = { "action": "event", "name":exchange, "data":msg }
		x = JSON.stringify(z)
		console.log(x)
		socket.send(x);
	}

	//socket.onerror = function(error) {
	//	p("Ошибка " + error.message + "<br>");
	//};
}
