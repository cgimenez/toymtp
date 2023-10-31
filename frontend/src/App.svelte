<script>
  import Fa from 'svelte-fa/src/fa.svelte'
  // @ts-ignore
  import {
    faArrowCircleLeft,
    faArrowCircleRight
  } from '@fortawesome/free-solid-svg-icons'

  import { onMount } from 'svelte'
  import {
    devices,
    selected_device,
    host_directory,
    device_directory
  } from './lib/store.js'
  import { connect, commands } from './lib/commands.js'
  import Panel from './lib/Panel.svelte'

  $: device_selected_files = $device_directory.entries.filter(
    (entry) => entry['selected'] == true
  )
  $: host_selected_files = $host_directory.entries.filter(
    (entry) => entry['selected'] == true
  )

  onMount(() => {
    connect()
  })

  let copy_to_host = () => {}

  let copy_from_host = () => {
    commands.copy_from_host(host_selected_files.map((f) => f.id))
  }

  let navigate_host_directory = (segment) => {
    commands.host_cd(segment)
    commands.host_getdir()
  }

  let navigate_device_directory = (segment) => {
    if (typeof segment === 'string') {
      segment = parseInt(segment)
    }
    commands.device_cd(segment)
    commands.device_getdir()
  }

  let select_device = () => {
    //console.log('Device selected ', $selected_device)
    commands.select_device($selected_device)
  }

  //$: console.log($selected_device)
</script>

<main class="container">
  <div class="row">
    <div class="col-12">
      <button class="small" on:click={commands.get_devices}>Get Devices</button>
      <button class="small" on:click={commands.host_getdir}>Get Host dir</button>
      <button class="small" on:click={commands.device_getdir}>Get Device dir</button>
      Device
      <select bind:value={$selected_device} on:change={() => select_device()}>
        {#each $devices as device}
          <option value={device}>
            {device}
          </option>
        {/each}
      </select>
    </div>
  </div>
  <div class="row">
    <Panel
      bind:directory={$host_directory}
      bind:navigate_directory_fn={navigate_host_directory}
      bind:selected_files={host_selected_files}
    />

    <div class="col-2 sep">
      <button
        disabled={device_selected_files.length == 0 || $selected_device == null}
        on:click={copy_to_host}
      >
        <Fa icon={faArrowCircleLeft} />
      </button>
      <button
        disabled={host_selected_files.length == 0 || $selected_device == null}
        on:click={copy_from_host}
      >
        <Fa icon={faArrowCircleRight} />
      </button>
    </div>

    <Panel
      bind:directory={$device_directory}
      bind:navigate_directory_fn={navigate_device_directory}
      bind:selected_files={device_selected_files}
    />
  </div>
</main>

<style>
  .container {
    width: 100% !important;
    max-width: unset;
  }

  .sep {
    width: 10%;
    margin: 0 8px;
  }

  .sep button {
    height: 40px;
    width: 70px;
    margin: 1rem 0;
  }

  .output {
    margin-top: 3px;
    border: 1px solid #aaaaaa;
    height: 100px;
  }
</style>
