import { defineConfig } from 'vite';
import vue from '@vitejs/plugin-vue';


import laravel from 'laravel-vite-plugin';

export default defineConfig({
    plugins: [
        vue(),
        laravel({
            input: [
                'resources/sass/app.scss',
                'resources/js/items/index.scss',
                'resources/js/items/index.js',
                'resources/js/wifi/index.scss',
                'resources/js/wifi/show.scss',
                'resources/js/wifi/index.js',
                'resources/js/app.js',
            ],
            refresh: true,
        }),
    ],
});
