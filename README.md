# bjornlindholm.com

Plain HTML with Tailwind CSS compiled by its CLI. Alpine handles the mobile menu.

## Develop

```sh
npm ci
npm start
```

Open http://localhost:8080. In a second terminal, run `npm run dev` to watch HTML and CSS changes and rebuild the stylesheet. Refresh the browser after editing.

## Edit

- `public/`: editable HTML pages and static assets. There is no template engine or Markdown build step.
- `styles/input.css`: Tailwind directives and custom prose styles.
- `tailwind.config.js`: scans all HTML in `public/`. Tailwind 3 preserves the previous CDN version's styling.
- `public/style.css`: generated and ignored by Git; do not edit directly.

Shared navigation is ordinary HTML repeated in each page. When adding a page, update the home/category listings and `public/sitemap.txt` manually.

## Build

```sh
npm run build
```

Deploy `public/` to any static host. The build only compiles CSS; it does not generate HTML. Directory indexes preserve existing page URLs. Redirects remain in `_redirects` for hosts that support it.

The former Paperstack templates and Markdown were converted once into the checked-in HTML. Their originals remain available in Git history.
