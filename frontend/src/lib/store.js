import { writable } from 'svelte/store';

export function getInitialDirectory() {
  return { entries: [], paths: [], meta: { writable: false, current: null } };
}

export const devices = writable([])
export const selected_device = writable()
export const host_directory = writable(getInitialDirectory())
export const device_directory = writable(getInitialDirectory())
