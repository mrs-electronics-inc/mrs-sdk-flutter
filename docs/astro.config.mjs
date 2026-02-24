// @ts-check
import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';

// https://astro.build/config
export default defineConfig({
	site: "https://flutter.mrs-electronics.dev",
	base: '/',
	integrations: [
		starlight({
			plugins: [],
			title: 'MRS Flutter SDK',
			social: [
				{ icon: 'github', label: 'GitHub', href: 'https://github.com/mrs-electronics-inc' },
				{ icon: 'gitlab', label: 'GitLab', href: 'https://gitlab.com/mrs-electronics' },
			],
			sidebar: [
				{
					label: "Getting Started",
					autogenerate: { directory: "getting-started" },
				},
			],
		}),
	],
});
