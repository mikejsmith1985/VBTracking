// The build this page is running.
//
// It exists so "it is still broken" and "you are running last week's copy" can be told
// apart in one glance, by whoever is holding the phone. Bump it with the service worker
// cache, which is the thing that actually decides what a device is running.
export const APP_VERSION = 'v10'
