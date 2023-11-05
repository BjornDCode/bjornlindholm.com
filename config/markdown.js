module.exports = {
	/*
	|--------------------------------------------------------------------------
	|   Link headlines
	|--------------------------------------------------------------------------
	|
	|   Specify if and how you want to wrap headlines with links.
	|   This is most commonly used on documentation websites.
	|
	|   Options:
	|   -  null     :  Disable autolinking of headlines  -  <h2>Headline 2</h2>
	|   - 'wrap'    :  Wrap link around headline text    -  <h2 id="headline-2"><a href="headline-2">Headline 2</a></h2>
	|   - 'after'   :  Add link after headline           -  <h2 id="headline-2">Headline 2</h2><a href="headline-2"></a>
	|   - 'append'  :  Add link after headline text      -  <h2 id="headline-2">Headline 2<a href="headline-2"></a></h2>
	|   - 'before'  :  Add link before headline          -  <a href="headline-2"></a><h2 id="headline-2">Headline 2</h2>
	|   - 'prepend' :  Add link before headline text     -  <h2 id="headline-2"><a href="headline-2"></a>Headline 2</h2>
	|
	*/

	linkHeadlines: null,

	/*
	|--------------------------------------------------------------------------
	|   External links
	|--------------------------------------------------------------------------
	|
	|   Specify whether you want to open external links in a new tab.
	|
	*/

	openExternalLinksInNewTab: true,
};
