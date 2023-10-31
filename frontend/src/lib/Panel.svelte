<script>
  import Fa from 'svelte-fa/src/fa.svelte'
  // @ts-ignore
  import { faFolder, faFile } from '@fortawesome/free-solid-svg-icons'
  import { onMount } from 'svelte'

  export let directory = {}
  export let navigate_directory_fn
  export let selected_files

  onMount(() => {})

  $: can_rm_entry = selected_files.length > 0 && directory.meta.writable == true
  $: can_rename_entry = selected_files.length == 1
  $: can_mkdir = directory.meta.writable == true

  const intl_date_format = new Intl.DateTimeFormat('default', {
    year: '2-digit',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
    hour12: false
  })

  function intl_date(d) {
    return intl_date_format.format(Date.parse(d))
  }

  function toggle_selected_entry(entry) {
    if ('selected' in entry) {
      delete entry['selected']
    } else {
      entry['selected'] = true
    }
  }

  function deselect_all_entries() {
    directory.entries.forEach((e) => delete e['selected'])
  }

  function select_entry(event, entry) {
    if (event.metaKey) {
      toggle_selected_entry(entry)
    } else {
      deselect_all_entries()
      toggle_selected_entry(entry)
    }
    directory.entries = directory.entries
  }

  function navigate_directory(folder, mode) {
    if (mode == 0 || folder.is_dir) {
      navigate_directory_fn(folder.id, mode)
      deselect_all_entries()
    }
  }
</script>

<div class="col-5 main">
  <div class="tools">
    <div class="row buttons">
      <button disabled={!can_mkdir} class="small">mkdir</button>
      <button disabled={!can_rm_entry} class="small">rm</button>
      <button disabled={!can_rename_entry} class="small">rename</button>
    </div>
    <div class="row breadcrumb">
      {#each directory.paths as path, index}
        <button on:click={() => navigate_directory(path, 0)}> {path.name} </button>
        {#if index < directory.paths.length - 1}
          &gt;
        {/if}
      {/each}
    </div>
  </div>

  <div class="row content">
    <table>
      {#each directory.entries as entry, i}
        <tr
          on:dblclick={() => navigate_directory(entry, 1)}
          on:click={(event) => select_entry(event, entry)}
          on:contextmenu|preventDefault={() => {}}
          class:selected={entry['selected'] == true}
        >
          <td>
            <Fa icon={entry.is_dir ? faFolder : faFile} />
          </td>
          <td width="50%">
            {entry.filename}
          </td>
          <td>
            {intl_date(entry.mtime)}
          </td>
          <td>
            {entry.size}
          </td>
        </tr>
      {/each}
    </table>
  </div>
</div>

<style>
  .main {
    border: 1px solid #aaaaaa;
    font-size: 90%;
  }

  .breadcrumb {
    cursor: pointer;
    margin: 0.2rem 0;
  }

  .content {
    overflow-y: scroll;
    height: 500px;
  }

  .tools {
    border-bottom: 1px solid #aaaaaa;
    padding: 0.2rem;
  }

  .buttons {
    margin: 0.2rem 0 0.5rem 0;
  }

  table {
    font-size: 90%;
  }

  table tr {
    height: 15px;
    cursor: pointer;
    user-select: none;
    -moz-user-select: none;
    -webkit-user-select: none;
    -ms-user-select: none;
  }

  table tr.selected {
    background-color: #f0f0f0;
  }
</style>
