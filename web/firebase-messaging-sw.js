importScripts('https://www.gstatic.com/firebasejs/10.7.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.7.1/firebase-messaging-compat.js');

importScripts('firebase-runtime.js');
firebase.initializeApp(self.firebaseRuntime);

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  // FCM muestra automáticamente payloads notification; no duplicarlos.
  if (payload.notification) return;
  const title = payload.notification?.title || 'Nueva notificacion';
  const options = {
    body:
      payload.notification?.body ||
      'Tienes una novedad en el sistema educativo.',
    icon: '/icons/Icon-192.png',
  };
  self.registration.showNotification(title, options);
});
