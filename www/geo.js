
$(document).ready(function() {

	var myMap;
	var allow_mark = false;
	var current_obj = null;
	var current_row = null;
	var host;
	var geolist;
	var colors;
	var curcolor;

	var ViewModel = function() {
		var self = this;
		self.host = ko.observable('empty');
		self.address = ko.observable();
		self.longitude = ko.observable();
		self.latitude = ko.observable();
		self.geolist = ko.observableArray([]);

		self.popupType = ko.observable(0);
		self.popupText = ko.observable('');

		self.locationButton = ko.observable('glyphicon-map-marker');
		
		self.setGeoList = function(list) {
			self.geolist(list);
		}
	
		self.setGeoObjectsOption = function(name,value)  {
			myMap.geoObjects.each(function(obj) {
				obj.options.set(name,value)
			});
		}
		self.findGeoObjectByProperty = function(name,value) {
			var r = null
			myMap.geoObjects.each(function(obj) {
				if ( obj.properties.get(name) == value ) {
					r = obj
				}
			});
			return r;		
		}
		self.setGeoObjectOption = function(obj,name,value) {
			obj.options.set(name,value)
		}

		self.setPopupMessage = function(type,message) {
			self.popupType(type);
			self.popupText(message);
		}

		self.setPopupMessage("alert-success","Выберите коммутатор из списка чтобы увидеть ево на карте.");
		
		self.setCoords = function(latitude,longitude) {
			self.latitude(latitude);
			self.longitude(longitude);
			$(current_row).find('td[data-bind="text: latitude"]').text(latitude);
			$(current_row).find('td[data-bind="text: longitude"]').text(longitude);
		}

		self.setAddress = function(address) {
			$(current_row).find('td[data-bind="text: address"]').text(address);
			self.address(address)
		}
		self.makePlacemark = function(host,coords,color,model,address) {
			self.setCoords(coords[0],coords[1])
			var o = self.findGeoObjectByProperty('id',host);
			if ( o != null ) {
				o.geometry.setCoordinates(coords);
			} else {
				o = new ymaps.Placemark(coords, {
					hintContent: host+"<br>"+model+"<br>"+address,
					id: host
				}, {
					preset: 'islands#redCircleIcon',
					iconColor: color
				});
				myMap.geoObjects.add(o);
			}
			return o;
		}

		/*
		 * Tree connection
		 */

		self.init_tree = function () {
			var g = {}
			$(geolist).each(function (i,x) {
				g[x['host']] = x;
			});
			geolist = g;
			//colors = ['#ff0000','#ff8000','#ffff00','#80ff00','#00ff00','#00ff80','#00ffff','#0080ff','#0000ff','#7f00ff','#ff00ff','#ff007f','#808080' ]
			colors = ['#0033FF']
			curcolor = 0
			self.tree('192.168.1.1');	// root switch
		}
		/*
		 * Если не указаны координаты, то точка не участвует в карте т.е не соединяется.
		 */
		self.tree = function (host) {

			var latitude = geolist[host]['latitude'];
			var longitude = geolist[host]['longitude'];
			console.log(" Host:"+host+" latitude:"+latitude+" longitude:"+longitude);
			$(geolist[host]['plist']).each( function (p,x) {
				dhst = x['host']
				if ( dhst == null ) return
				if ( geolist[dhst] == undefined ) return

				var dlatitude = geolist[dhst]['latitude'];
				var dlongitude = geolist[dhst]['longitude'];
				if ( dlatitude == null || dlongitude == null ) return
				var myPolyline = new ymaps.Polyline([
					[latitude,longitude],
					[dlatitude,dlongitude]
				], {
					balloonContent: "Логическое соедиение."
				}, {
					balloonCloseButton: false,
					strokeColor: self.nextcolor(),
					strokeWidth: 4,
					strokeOpacity: 0.5
				});
				myMap.geoObjects.add(myPolyline);
				console.log(" to host:"+dhst+" latitude:"+dlatitude+" longitude:"+dlongitude);
				self.tree(dhst);
			});
		}

		self.nextcolor = function () {
			var c;
			c = colors[curcolor]
			curcolor = curcolor + 1
			if ( curcolor >= colors.length ) curcolor = 0;
			return c;
		}

		/*
		 * Events
		 */

		self.markDragEnd = function (e) {
			var coords = current_obj.geometry.getCoordinates();
			self.setCoords(coords[0],coords[1])
			var a = self.geocodeByCoords(coords,function (addr) { 
				self.setAddress(addr);
			});
		}
		/*
		 * ajax
		 */
		self.getAjaxGeoList = function() {
			$.ajax({
				url: '/storm/geolist',
				data: { },
				dataType : "json",
				success: function (data, textStatus) {
					if ( data.status == "ok" ) {
						geolist=data.geolist;
						/*$(data.geolist).each( function (k,x) {
							if ( x['hostname'] == null) return;
							var r = x['hostname'].split("-");
							$(r).each( function( n,z ) {	
								if ( self.validate(z) && z.length > 3 ) {
									if ( x['address'] == null ) {
										x['address'] = z.replace(/([A-Za-z_]+\d+)d(\d+)/,'$1/$2');
										var adr = 'Magnitogorsk, '+x['address'];
										ymaps.geocode(adr, {
											results: 1
										}).then(function (res) {
											var firstGeoObject = res.geoObjects.get(0),
											coords = firstGeoObject.geometry.getCoordinates(),
											bounds = firstGeoObject.properties.get('boundedBy');
											x['latitude'] = coords[0];
											x['longitude'] = coords[1];
											x['address'] = firstGeoObject.properties.get('name');
											o = self.makePlacemark(x['host'],coords,'blue');
											self.setGeoList(data.geolist);
										});
										return;
									}
								}
							});
						});*/
						// создаем геообъекты на карте
						$(data.geolist).each(function (k,x) {
							if ( x['latitude'] != null && x['longitude'] != null ) {
								o = self.makePlacemark(x['host'],[x['latitude'],x['longitude']],'blue',x['hostname'],x['address']);
							}
						});	

						self.setGeoList(data.geolist);
						self.init_tree();
						//self.setGeoList(data.geolist);
					} else {
						self.setPopupMessage("alert-warning","Произошла ошибка при загрузке листа коммутаторов.");
					}
				}
			}).fail(function () {
				self.setPopupMessage("alert-warning","Ошибка подключения при ajax запросе.");
			});

		}

		self.validate = function(val) {
			var matches = val.match(/\d+/g);
			if (matches == null) return null
			var matches = val.match(/[A-Za-z_]+/g);
			if (matches == null) return null
			return true
		}

		/*
		 * ya map 
		 */
		self.yainit = function () {
		
			// Создаем карту.
			myMap = new ymaps.Map("map", {
				center: [ 53.39, 58.98],
				zoom: 12,
				controls: ['zoomControl', 'searchControl', 'typeSelector',  'fullscreenControl']

			}, {
				searchControlProvider: 'yandex#search'
			});

			// double bind click
			myMap.events.add('dblclick', self.ya_dblclick);
			
			//
			self.getAjaxGeoList();
		}

		self.ya_dblclick = function (e) {
			// Создание объекта возможно только если кнопка нажата и объекта нету.	
			if ( allow_mark && current_obj == null ) {
				if (!myMap.balloon.isOpen()) {
					var coords = e.get('coords');
					var a = self.geocodeByCoords(coords,function (addr) { 
						self.setAddress(addr);
					});
					current_obj = self.makePlacemark(host,coords,'green','','');
					self.setGeoObjectOption(current_obj,"iconColor","green")
					current_obj.options.set("draggable",true);
					current_obj.events.add(['dragend'],self.markDragEnd);
				} else {
					myMap.balloon.close();
				}
			}
			e.preventDefault();
			e.stopPropagation();
			return false;
		}

		/*
		 * select list
		 */

		self.selectRow = function(row,e) {
			console.log(row)
			if ( allow_mark ) {
				self.setPopupMessage("alert-warning","Завершите изменение координат объекта, нажатием на галку.");
				return;
			} 
			self.host(row['host'])
			self.address(row['address'])
			self.longitude(row['longitude'])
			self.latitude(row['latitude'])
			// prev unset
			$(current_row).css("background","#ffffff")
			if ( current_obj != null ) {
				current_obj.options.set("draggable",false);
			}
			// new
			current_row = e.currentTarget;
			$(current_row).css("background","#eeeeee")
			host = $(current_row).find('td[data-bind="text: host"]').text();
			self.setGeoObjectsOption('iconColor','blue');
			current_obj = self.findGeoObjectByProperty("id",row['host'])
			if ( current_obj != null ) {
				self.setGeoObjectOption(current_obj,"iconColor","red")
				myMap.setCenter(current_obj.geometry.getCoordinates());
				var z = current_obj.options.get("zIndex")
				var x = current_obj.options.get("visible")
				console.log(z)
				self.setGeoObjectsOption('zIndex','100');
				current_obj.options.set("zIndex","1000");
				current_obj.options.set("visible",true);
			} else {
				self.setPopupMessage("alert-success","Укажите адрес или нажмите на буй чтобы переместить устройство на карте.");
			}
		}

		/*
		 * Buttons
		 */
		self.saveAll = function() {
			$.ajax({type: 'post',
				url: '/storm/geosave',
				data: JSON.stringify({ 'list': geolist }),
				dataType : "json",
				success: function (data, textStatus) {
					if ( data.status == "ok" ) {
						self.setPopupMessage("alert-success","Новые координаты устройства сохранены.");
					} else {
						self.setPopupMessage("alert-warning","Ошибка не найден коммутатор для которого устанавливаются координаты.");
					}
				}
			}).fail(function () {
				self.setPopupMessage("alert-warning","Ошибка подключения при ajax запросе.");
			});
			return;
			myMap.geoObjects.each(function(obj) {
				console.log(obj.properties.get('id'));
				console.log(obj.geometry.getCoordinates());
			});
		}
		self.markLocation = function() {
			if ( current_row == null ) {
				self.setPopupMessage("alert-warning","Коммутатор не выбран, пожалуйста выберите коммутатор.");
				return;
			}
			allow_mark = !allow_mark;		
			if ( allow_mark ) {
			// Режим редактирования
				self.locationButton('glyphicon-ok');		
				if ( current_obj != null ) {
					current_obj.options.set("draggable",true);
					current_obj.events.add(['dragend'],self.markDragEnd);
					self.setGeoObjectOption(current_obj,"iconColor","green")
					self.setPopupMessage("alert-success","Перетащите зеленый кружок в новое место и нажмите галку.");
				} else {
					self.setPopupMessage("alert-success","Укажите координаты коммутатора двойным щелчком на карте.");
				}
			} else {
			// Выход из редактирования
				self.locationButton('glyphicon-map-marker');		
				if ( current_obj != null ) {
					current_obj.options.set("draggable",false);
					current_obj.events.remove('dragend');
					self.setGeoObjectOption(current_obj,"iconColor","red")

					$.ajax({type: 'post',
						url: '/storm/geosave',
						data: JSON.stringify({ 'list': [{ 'host': host , 'address' : self.address(), 'latitude' : self.latitude() , 'longitude' : self.longitude() }] }),
						dataType : "json",
						success: function (data, textStatus) {
							if ( data.status == "ok" ) {
								self.setPopupMessage("alert-success","Новые координаты устройства сохранены.");
							} else {
								self.setPopupMessage("alert-warning","Ошибка не найден коммутатор для которого устанавливаются координаты.");
							}
						}
					}).fail(function () {
						self.setPopupMessage("alert-warning","Ошибка подключения при ajax запросе.");
					});
				} else {
					self.setPopupMessage("alert-warning","Координаты небыли указаны.");
				}
			}
		}

		self.geocodeAddress = function() {
			if ( current_row == null ) {
				self.setPopupMessage("alert-warning","Коммутатор не выбран, пожалуйста выберите коммутатор.");
				return;
			}
			var adr = 'Магнитогорск, '+self.address();		
			ymaps.geocode(adr, {
				results: 1
			}).then(function (res) {
				var firstGeoObject = res.geoObjects.get(0),
				coords = firstGeoObject.geometry.getCoordinates(),
				bounds = firstGeoObject.properties.get('boundedBy');

				self.setAddress(self.address());

				current_obj = self.makePlacemark(host,coords,'green','','')
				// Включаем режим редактирования
				allow_mark = false
				self.markLocation();

				myMap.setBounds(bounds, {
					checkZoomRange: true
				});
			});
		}

		// geocode
		self.geocodeByCoords = function(coords,callback) {
			ymaps.geocode(coords).then(function (res) {
				var firstGeoObject = res.geoObjects.get(0);
				r = firstGeoObject.properties.get('name');
				callback(r);
			});
		}
	


	}; 
	var koViewModel = new ViewModel([]);
	ko.applyBindings(koViewModel);

	ymaps.ready(koViewModel.yainit);


});

