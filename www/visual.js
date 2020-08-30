
$(document).ready(function() {
	self = this;
	self.nodes = [];
	self.edges = [];

	var LENGTH_MAIN = 500,
	LENGTH_SERVER = 150,
	LENGTH_SUB = 50,
	WIDTH_SCALE = 1,
	GREEN = 'green',
	RED = '#C5000B',
	ORANGE = 'orange',
	GRAY = 'gray',
	BLACK = '#2B1B17';

	self.getGeoData = function () {

		$.ajax({
			url: '/storm/geolist',
			data: { },
			dataType : "json",
			success: function (data, textStatus) {
				$(data.geolist).each(function (i,x){
					
					// nodes
					self.nodes.push({
						id: x['host'],
						label: x['host'] ,
						group: 'switch',
						value: 4
					});
					
					// edges
					$(x.plist).each(function (n,z) {
						self.edges.push({
							from: x['host'],
							to: z['host'],
							length: LENGTH_MAIN, 
							width: WIDTH_SCALE * 6, 
							label: '1Gbps'
						});
					});
				});
				self.visInit();
			}
		});
	}
	
	self.visInit = function () {
	
		// legend
		var mynetwork = document.getElementById('mynetwork');
		var x = - mynetwork.clientWidth / 2 + 50;
		var y = - mynetwork.clientHeight / 2 + 50;
		var step = 70;
		// create a network
		var container = document.getElementById('mynetwork');
		var data = {
			nodes: self.nodes,
			edges: self.edges
		};
//		var options = {
//			enabled:true,
//			stabilize: false,   // stabilize positions before displaying
//			physics:{
//				enabled: true,
//				barnesHut: {
//					gravitationalConstant: -2000,
//					centralGravity: 0.3,
//					springLength: 95,
//					springConstant: 0.04,
//					damping: 0.09,
//					avoidOverlap: 0
//				},
//				forceAtlas2Based: {
//					gravitationalConstant: -50,
//					centralGravity: 0.01,
//					springConstant: 0.08,
//					springLength: 100,
//					damping: 0.4,
//					avoidOverlap: 0
//				},
//				repulsion: {
//					centralGravity: 0.2,
//					springLength: 200,
//					springConstant: 0.05,
//					nodeDistance: 100,
//					damping: 0.09
//				},
//				hierarchicalRepulsion: {
//					centralGravity: 300.0,
//					springLength: 500,
//					springConstant: 0.01,//0.01,
//					nodeDistance: 700,
//					damping: 10
//				},
//				maxVelocity: 50,
//				minVelocity: 0.1,
//				solver: 'hierarchicalRepulsion',
//				stabilization: {
//					enabled: true,
//					iterations: 1000,
//					updateInterval: 100,
//					onlyDynamicEdges: false,
//					fit: true
//				},
//				timestep: 0.5,
//				adaptiveTimestep: true
//			},
//			nodes: {
//				radiusMin: 16,
//				radiusMax: 32,
//				fontColor: BLACK
//			},
//			edges: {
//				color: GRAY
//			},
//			groups: {
//				'switch': {
//					shape: 'triangle',
//					color: '#FF9900' // orange
//				},
//				desktop: {
//					shape: 'dot',
//					color: "#2B7CE9" // blue
//				},
//				mobile: {
//					shape: 'dot',
//					color: "#5A1E5C" // purple
//				},
//				server: {
//					shape: 'square',
//					color: "#C5000B" // red
//				},
//				internet: {
//					shape: 'square',
//					color: "#109618" // green
//				}
//			}
//		}

		var options = {
			smoothCurves: false,
			nodes: {
				shape: 'dot',
				size: 16
			},
			physics: {
				enabled: false
			}
		};
		self.network = new vis.Network(container, data, options);
	}

	// on ready
	
	self.getGeoData();


});
