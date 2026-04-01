export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    const path = url.pathname;

    // Rewrite dynamic routes to static HTML files
    if (/^\/s\/\d+$/.test(path)) {
      url.pathname = '/book-tour-session.html';
      return env.ASSETS.fetch(url);
    }

    if (/^\/t\/\d+$/.test(path)) {
      url.pathname = '/select-tour-session.html';
      return env.ASSETS.fetch(url);
    }

    // Override Content-Type for assetlinks.json
    if (path === '/.well-known/assetlinks.json') {
      const response = await env.ASSETS.fetch(request);
      return new Response(response.body, {
        status: response.status,
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
      });
    }

    // Static assets
    return env.ASSETS.fetch(request);
  }
};
