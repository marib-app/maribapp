import _ from 'lodash';
window._ = _;

import 'bootstrap';

/**
 * We'll load the axios HTTP library which allows us to easily issue requests
 * to our Laravel back-end. This library automatically handles sending the
 * CSRF token as a header based on the value of the "XSRF" token cookie.
 */

import axios from 'axios';
window.axios = axios;

window.axios.defaults.headers.common['X-Requested-With'] = 'XMLHttpRequest';

/**
 * Echo exposes an expressive API for subscribing to channels and listening
 * for events that are broadcast by Laravel. Echo and event broadcasting
 * allows your team to easily build robust real-time web applications.
 */

window.ChatPresence = window.ChatPresence || {
    join: () => null,
    leave: () => undefined,
};

const pusherKey = import.meta.env.VITE_PUSHER_APP_KEY ?? '';

if (pusherKey && typeof window.Pusher !== 'undefined' && typeof window.Echo === 'function') {
    const cluster = import.meta.env.VITE_PUSHER_APP_CLUSTER ?? 'mt1';
    const configuredHost = import.meta.env.VITE_PUSHER_HOST;
    const scheme = import.meta.env.VITE_PUSHER_SCHEME ?? (configuredHost ? 'http' : 'https');
    const defaultPort = scheme === 'https' ? 443 : 80;
    const port = Number(import.meta.env.VITE_PUSHER_PORT ?? defaultPort);
    const forceTLS = scheme === 'https' || !configuredHost;

    const echoOptions = {
        broadcaster: 'pusher',
        key: pusherKey,
        cluster,
        forceTLS,
        encrypted: forceTLS,
        enabledTransports: ['ws', 'wss'],
        disableStats: true,
        authorizer: (channel) => ({
            authorize(socketId, callback) {
                window.axios.post('/broadcasting/auth', {
                    socket_id: socketId,
                    channel_name: channel.name,
                }).then((response) => {
                    callback(false, response.data);
                }).catch((error) => {
                    console.error('Broadcast authorization failed', error);
                    callback(true, error);
                });
            },
        }),
    };

    if (configuredHost) {
        echoOptions.wsHost = configuredHost;
        echoOptions.wsPort = port;
        echoOptions.wssPort = port;
    } else {
        echoOptions.wsHost = `ws-${cluster}.pusher.com`;
        echoOptions.wsPort = port;
        echoOptions.wssPort = port;
    }

    const EchoConstructor = window.Echo;
    window.Echo = new EchoConstructor(echoOptions);

    window.ChatPresence = {
        join(conversationId, handlers = {}) {
            if (!window.Echo || !conversationId) {
                return null;
            }

            const channelName = `chat.conversation.${conversationId}`;
            const channel = window.Echo.join(channelName);

            if (handlers.here) {
                channel.here((users) => handlers.here(users));
            }

            if (handlers.joining) {
                channel.joining((user) => handlers.joining(user));
            }

            if (handlers.leaving) {
                channel.leaving((user) => handlers.leaving(user));
            }

            if (handlers.onMessage) {
                channel.listen('MessageSent', (event) => handlers.onMessage(event));
            }

            if (handlers.onTyping) {
                channel.listen('UserTyping', (event) => handlers.onTyping(event));
            }

            if (handlers.onPresence) {
                channel.listen('UserPresenceUpdated', (event) => handlers.onPresence(event));
            }

            return channel;
        },

        leave(conversationId) {
            if (window.Echo && conversationId) {
                window.Echo.leave(`chat.conversation.${conversationId}`);
            }
        },
    };


    if (typeof window.Echo?.private === 'function') {
        try {
            window.Echo.private('admin.notifications')
                .listen('AdminDashboardNotification', (event) => {
                    const notification = event?.notification ?? {};
                    const messageParts = [notification.title, notification.message].filter(Boolean);
                    const toastMessage = messageParts.join(' - ') || 'New admin notification received.';

                    if (typeof window.showSuccessToast === 'function') {
                        window.showSuccessToast(toastMessage);
                    } else {
                        console.info('AdminDashboardNotification', notification);
                    }

                    const badge = document.querySelector('[data-admin-notification-badge]');
                    if (badge) {
                        const current = Number.parseInt(badge.textContent ?? '0', 10) || 0;
                        badge.textContent = String(current + 1);
                        badge.classList.remove('d-none');
                    }
                })
                .error((error) => {
                    console.error('Admin notifications channel error', error);
                });
        } catch (error) {
            console.error('Failed to subscribe to admin notifications channel', error);
        }
    }

} else {
    console.warn('Real-time chat setup skipped. Ensure Pusher and Laravel Echo scripts are loaded and credentials are configured.');
}
