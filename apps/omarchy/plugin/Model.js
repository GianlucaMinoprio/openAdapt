.pragma library

var palette = [
  {id:"cyan", name:"Cyan", hex:"#00ffff"}, {id:"sky", name:"Sky", hex:"#003cff"},
  {id:"blue", name:"Blue", hex:"#0000ff"}, {id:"purple", name:"Purple", hex:"#6400c8"},
  {id:"pink", name:"Pink", hex:"#ff0a50"}, {id:"red", name:"Red", hex:"#f00008"},
  {id:"coral", name:"Coral", hex:"#ff1003"}, {id:"orange", name:"Orange", hex:"#ff2800"},
  {id:"yellow", name:"Yellow", hex:"#ffff00"}, {id:"lime", name:"Lime", hex:"#78f000"},
  {id:"green", name:"Green", hex:"#14f000"}, {id:"white", name:"White", hex:"#ffffff"}
];
function snap(value) { return Math.max(0, Math.min(100, Math.round(Number(value) / 5) * 5)); }
function clone(value) { return JSON.parse(JSON.stringify(value)); }
function color(id) {
  for (var i=0; i<palette.length; ++i) if (palette[i].id === id) return palette[i].hex;
  return "#9bdacb";
}
function blank() {
  return {saved_pairs:[], selected_id:null, connected:false, busy:false, operation:"", pair_name:"", message:"", failed:false, feet:{
    left:{connected:false,connection:"disconnected",percent:0,battery:null,color:null,lights:"unknown",status:"saved",checked_at:null,battery_checked_at:null},
    right:{connected:false,connection:"disconnected",percent:0,battery:null,color:null,lights:"unknown",status:"saved",checked_at:null,battery_checked_at:null}}};
}
function disconnected(value) {
  var next = clone(value);
  next.connected = false; next.busy = false; next.operation = "";
  ["left", "right"].forEach(function(side) { next.feet[side].connected = false; next.feet[side].connection = "disconnected"; });
  return next;
}
function lastChecked(value) {
  if (!value) return "Not checked yet";
  var mins = Math.max(0, Math.floor((Date.now()/1000 - value)/60));
  if (mins < 1) return "Checked just now";
  if (mins < 60) return "Checked " + mins + "m ago";
  if (mins < 1440) return "Checked " + Math.floor(mins/60) + "h ago";
  return "Last saved reading";
}
