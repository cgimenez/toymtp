# A skeleton of a MTP transfer tool written in Crystal language.

I've lost interest, because coding a MTP tool is not that fun ;-)

- backend  -> Crystal, Crystal http server
- frontend -> app is coded in Svelte, viewed through a WebView
- frontend talks to backend using Websockets

May be you wonder why I didn't choose to make the frontend to talk to the backend via a kind of bridge between the Crystal side and the Javascript side (which is doable).

The answer is :

- you'll need to recompile the app if the client side code changes
- using the browser's dev tools if a PITA with webviews (reopen dev tools each time, losing the previous state, eg. if the network tab was opened you'll have to reopen it)
- on the other end with websockets and if you have a stablized backend, you can rebuild the client, reload the browser's view whilst keeping the dev tools opened

But Crystal is a really cool language, worth to try !