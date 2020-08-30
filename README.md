
Мини "фреймворк" для управления сетевыми устройствами через cli(telnet/ssh).
Работал в production реальной компании, код грязный.

Зачем через cli ? Почему не snmp ? Можно и snmp но во многих случаях
то что можно по telnet не всегда есть в snmp или mib не всегда свеж и доступен.
А телнет или ssh есть в подавляюещем большинстве вендоров.

Задачи которые решал фреймворк: 
1) сборка карты коммутаторов в сети по информации о маках в управляющем vlan и визуальное отображение через веб интерфейс.
2) резервеное копировение конфигураций устройств, независимо от их вендоров по базе.
3) отображение информации геолокации устройств и привязка их к карте на yandex.map
4) экспериментальная диагностика порта - состояние порта, получение мака порта, получение счетчиков ошибок/трафика порта, в случае pon уровня сигнала.
5) поиск порта абонента по маку с учетом постороенной карты коммутаторов.
6) сервис для поиска и подписывания порта абонента при авторизации на BRAS.
7) сборка информации об устройствах - состояние портов, скорость портв, маки за портами и другой и работа с этой базой через sqlite в веб интерфейсе.
8) облегчение включение опции на многих устройствах разных вендоров путем написания скрипта и использования фреймоворка.

 Содержимое:

*app* - утилиты для работы с фреймворком  
*core* - классы ядра фреймворка  
*db* - сюда пишутся sqlite базы  
*INSTALL.txt* - то что нужно для работы  
*log* - сюда пишутся логи  
*macrefresh.sh* - скрипт для обновление arp таблицы маков для устройств  
*modules* - ООП шаблоны функционала устройств с наследованием использующие библиотеку собственной реализации miniexpect  
*template* - Шаблоны erb для web интерфейса  
*tmuxstorm* - скрипт для rc.d  
*ttywrap.sh* - обертка изменения размера консоли для некоторых устройств  
*www* - js/css/web files  
*zmake_all.sh* - скрипт сканирования сети, сбора маков с устройств, сбора дополнительной информации о портах, генерирования статической карты  
*zmake_hostdiscovery.sh* - дисковер хостов в базу sqlite  
*zmake_info.sh* - сбор информации об устройствах в базе через получение конфигурации  
*zmake_map.sh* - сбор маков в управляющем vlan для посмтроение связанной карты устройств  
*zmake_recovery.sh* - если чтото не соединилось повторное сканирование и попытка сбора карты  

*core/*  
*amqp.rb*	- класс обертка для подключение и работы с amqp  
*taskcontrol.rb* - раньше управлял задачами через amqp  
*taskservice.rb* - раньше отдавал вывод от утилит diagport, searchport был через amqp  
*exchange.rb* - использовался вместе с taskservice  
*db_mysql_billing.rb* - класс с функциями работы с bgbilling  
*db.rb* - класс для работы со sqlite  
*db_billing.rb* - класс работы с sqlite базой биллинга - сюда складываются найденные мак порт и ид договора клиента  
*erbcontext.rb* - класс для прокидывания переменных в шаблоны erb  
*mapui.rb* - класс для консольного отображения дерева карты  
*config.rb.exmaple* - пример конфигурации  
*patterns.rb* - паттерны распознования устройств и назначения им ООП класса шаблона функций  
*miniexpect.rb* - класс miniexpect для удобного поиска паттернов в выводе  
*manager.rb* - создает инстанцию подключения к устройству Miniexpect передает ещё классу Switch и вызывает интерактивное определение версии устройства, на выходе уже инстанция определенного вендора  
*switch.rb* - базовый класс авторизации на устройство, определения модели  
*protocols.rb* - класс для определения функций обработки протоколов telnet  
*threadpusher.rb* - класс для паралельной работы с устройствами в тредах  
*taskstate.rb* - класс который отображает прогресс выполнения утилит через amqp  
*wsapi.rb* - класс для запуска и отображение потока вывода от утилит diagport/searchport через websocket  
*wsc.rb* - класс обертки websockets event machine  
*debug.rb* - класс отладки  
*paramfilter.rb* - класс для построения структурированных объектов конфигурации по конфигурации устройств  
*utils.rb* - функции, поиск порта по маку  

*app/*  
*amqp_exec.rb* - amqp сервис для запуска задач  
*collector.rb* - сбор маков на устройстве в vlan в базу sqlite  
*geo_import_txt.rb* - импорт геолокации из sqlite в txt  
*getinfo.rb* - сбор данных из конфигурации устройств, состояние портов  
*htmlgen.rb* - генерация карты из собранных маков vlan'а управления  
*map_links_export_tozabbix.rb* - экспорт связей хостов в заббикс  
*search2.rb* - поиск порта по маку  
*taskchange.rb* - изменение состояние задачи  
*webservice.rb* - сервис подписывания портов при авторизации биллинга - биллинг кидает запрос сюда  
*arpresolver.rb* - получение арп таблицы с устройства  
*diagport2.rb* - диагностика порта  
*disable_services.rb* - пример отключение опции services  
*geo_import_zabbix.rb* - импорт данных геолокации из заббикса  
*getportrates.rb* - получение загруженности портов  
*httpd.rb* - веб сервис  
*nmap_xmlparser.rb* - парсер xml вывода nmap с записью в sqlite  
*search3verb.rb* - поиск порта по маку с отладкой  
*tocore_pinger.rb* - пинг с устройства  
*bkpcfg.rb* - бэкапирование конфигурации через tftp или ssh  
*diagport.rb* - диагностика порта  
*fromcore_pinger.rb* - пинг с устройства  
*geteponsignal.rb* - получение сигнала порта  
*getportstate.rb* - получение состояния порта  
*map_links_export_totxt.rb* - экспорт связей в txt  
*portfinder.rb* - сервис поиска портов для биллинга работает через очередь с webservice.rb  
*set_logging.rb* - пример включение логгирования на всех устройствах  
*verify_bkp.rb* - скрипт проверки бэкапов  

Пример:
```ruby
#!/usr/bin/ruby
require 'rubygems'
require 'date'
require 'optparse'
require_relative '../core/miniexpect.rb'
require_relative '../core/manager.rb'
require_relative '../core/debug.rb'
require_relative '../core/db.rb'
require_relative '../core/threadpusher.rb'
require 'thread'
require 'thwait'

# максимально количество тредов по дефолту
options = { :maxthreads => 10 }

OptionParser.new do |opts|
	opts.banner = "Usage: example.rb [options]"

	opts.on("-m", "--max-threads MAX", "Max threads") do |v|
		options[:maxthreads] = v.to_i
	end

	opts.on("-h", "--host HOST", "Single host") do |v|
		options[:host] = v
	end

	opts.on_tail("-h", "--help", "Show this message") do
		puts opts
		exit
	end
end.parse!

#
# start
#

# открываем базу, которая собирается через ./zmake_all.sh
db = Db.new

# если указан хост то получаем его открытые порты из базы
# это нужно чтобы понимать как к нему подключаться через telnet или ssh
if options[:host] != nil
	hosts = [db.getHost(options[:host])]	
else
	hosts = db.getHostsWithServices()
end

# будем работать параллельно в потоках
p = ThreadPusher.new()
# callback потоков чтобы не блокировать транзакции к sqlite если коммутатор зависнет

p.setThreadDataWorker() do |t|
# в данном случае нам нечего сохранять в базу
end

# создаем потоки из массива hosts
p.pushThreads(options[:maxthreads],hosts) do |row|

	# получаем хост
	host = row['host']
	# получаем открытые порты	
	ports = row['services'].split(",").sort { |x,y| y.to_i <=> x.to_i } 
	port = ports[0].to_i
	# выводим отладку	
	pinfo "Start thread host=#{host} port=#{port}"
	p row
	# сохраняем переменные в контексте thread чтобы использовать в callback
	Thread.current["id"] = row['id']
	Thread.current["host"] = host
	pinfo "Set severity #{host}"
	# SwitchManger создаем соединение  
	sm = SwitchManager.new(host,port)
	# Авторизуемся, определяем версию, получаем инстанцию 
	# шаблона модели из ./modules наследованную от Switch
	wrk = sm.getContainer()
	# если не ноль то всё хорошо
	if wrk == nil
		Thread.current["list"] = nil
		Thread.exit()
	end
	# если версия модели коммутатора не 2900 то выходим 
	if wrk.version != '2900'
		wrk.exit()
		Thread.exit()
	end
	# входим в enable
	wrk.enableMode()
	# входим в режим конфигурирование коммутатора
	wrk.ConfigurationMode do 
		# устанавливаем опцию
		wrk.setLogging("192.168.1.1")
	end
	# пишем конфиг
	wrk.writeCfg()
	# выходим с устройства
	wrk.exit()
	pinfo "Exited"
	sm = nil
	GC.start
end



```

