import { get } from 'svelte/store'
import { devices, selected_device, host_directory, device_directory, getInitialDirectory } from "./store.js";

let socket;

function backend_ws_url() {
  return `ws://localhost:3000`
}

function new_connection() {
  socket = new WebSocket(backend_ws_url())
  /*socket.addEventListener("error", (event) => {
    setTimeout(() => new_connection(), 2000)
  })*/
}

export const connect = () => {
  new_connection()

  socket.addEventListener("open", (event) => {
    commands.host_getdir()
    commands.get_devices()
  });

  socket.addEventListener("close", (event) => {
    setTimeout(() => new_connection(), 2000)
  });

  socket.addEventListener('message', function (event) {
    const response = JSON.parse(event.data);
    const msg = response["msg"]
    const data = response["data"]

    console.log("Socket recv :", msg, data)
    switch (msg) {
      case "DEVICE_CONNECTED":
        device_directory.set(getInitialDirectory())
        selected_device.set(data)
        break;

      case "STORAGE_AVAILABLE":
        commands.device_getdir()
        break;

      case "DEVICE_DISCONNECTED":
        device_directory.set(getInitialDirectory())
        break;

      case "DEVICES":
        data.unshift(" ")
        devices.set(data)
        //selected_device.set(data.slice(-1)[0])
        device_directory.set(getInitialDirectory())
        break;

      case "HOSTDIR":
        host_directory.set(data)
        break;

      case "DEVICEDIR":
        device_directory.set(data)
        break;

      case "COPY_END":
        commands.device_getdir()
        break;
    }
  })
}

export const commands = {
  "host_cd": (segment_id) => {
    send_msg("HOST_CD", { id: segment_id })
  },
  "host_getdir": () => {
    send_msg("HOST_GETDIR", "")
  },

  "get_devices": () => {
    send_msg("GET_DEVICES", "")
  },
  "select_device": (device) => {
    send_msg("SELECT_DEVICE", device)
    send_msg("SELECT_STORAGE", "")
    commands.device_getdir()
  },
  "device_cd": (segment_id) => {
    send_msg("DEVICE_CD", { id: segment_id })
  },
  "device_getdir": () => {
    send_msg("DEVICE_GETDIR", "")
  },

  "copy_from_host": (files) => {
    send_msg("COPY_FROM_HOST", { params: { files: files, destination: get(device_directory).meta.current } })
  }
}

function send_msg(msg, params) {
  console.log("Socket send :", msg, params)
  socket.send(
    JSON.stringify({ "msg": msg, "params": params })
  )
}