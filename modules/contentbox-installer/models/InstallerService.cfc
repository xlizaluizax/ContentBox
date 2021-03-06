/**
 * ContentBox - A Modular Content Platform
 * Copyright since 2012 by Ortus Solutions, Corp
 * www.ortussolutions.com/products/contentbox
 * ---
 * Installs ContentBox
 */
component accessors="true" {

	// DI
	property name="authorService"       inject="authorService@cb";
	property name="settingService"      inject="settingService@cb";
	property name="categoryService"     inject="categoryService@cb";
	property name="pageService"         inject="pageService@cb";
	property name="entryService"        inject="entryService@cb";
	property name="commentService"      inject="commentService@cb";
	property name="contentStoreService" inject="contentStoreService@cb";
	property name="roleService"         inject="roleService@cb";
	property name="permissionService"   inject="permissionService@cb";
	property name="securityRuleService" inject="securityRuleService@cb";
	property name="appPath"             inject="coldbox:setting:applicationPath";
	property name="coldbox"             inject="coldbox";

	/**
	 * Constructor
	 */
	InstallerService function init(){
		permissions = {};
		return this;
	}

	/**
	 * Execute the installer
	 * @setup The setup object
	 */
	function execute( required setup ){
		transaction {
			// process rerwite
			if ( arguments.setup.getFullRewrite() ) {
				processRewrite( arguments.setup );
			}
			// create roles
			var adminRole = createRoles( arguments.setup );
			// create Author
			var author    = createAuthor( arguments.setup, adminRole );
			// Create settings according to setup
			createSettings( arguments.setup );
			// create all security rules
			createSecurityRules( arguments.setup );
			// Do we create sample data?
			if ( arguments.setup.getpopulateData() ) {
				createSampleData( arguments.setup, author );
			}
			// Remove ORM update from Application.cfc
			// Commented out for better update procedures.
			// processORMUpdate( arguments.setup );
			// Process reinit and debug password security
			processColdBoxPasswords( arguments.setup );
			// ContentBox is now online, mark it:
			settingService.activateCB();
			// Reload Security Rules
			coldbox
				.getInterceptorService()
				.getInterceptor( "cbSecurity@contentbox-security" )
				.loadRules();
		}
	}

	/**
	 * Create settings from setup
	 * @setup The setup object
	 */
	function createSettings( required setup ){
		var settings = {
			"cb_site_name" : arguments.setup.getSiteName(),
			"cb_site_tagline" : arguments.setup.getSiteTagLine(),
			"cb_site_description" : arguments.setup.getSiteDescription(),
			"cb_site_keywords" : arguments.setup.getSiteKeywords(),
			"cb_site_email" : arguments.setup.getSiteEmail(),
			"cb_site_outgoingEmail" : arguments.setup.getSiteOutgoingEmail(),
			"cb_site_mail_server" : arguments.setup.getcb_site_mail_server(),
			"cb_site_mail_username" : arguments.setup.getcb_site_mail_username(),
			"cb_site_mail_password" : arguments.setup.getcb_site_mail_password(),
			"cb_site_mail_smtp" : arguments.setup.getcb_site_mail_smtp(),
			"cb_site_mail_tls" : arguments.setup.getcb_site_mail_tls(),
			"cb_site_mail_ssl" : arguments.setup.getcb_site_mail_ssl()
		};

		// Update settings according to setup options
		var aSettings = [];
		for ( var thisSetting in settings ) {
			var oSetting = settingService.findByName( thisSetting );
			oSetting.setValue( settings[ thisSetting ] );
			arrayAppend( aSettings, oSetting );
		}
		// Save all settings
		settingService.saveAll( aSettings );
	}

	/**
	 * Create security rules
	 * @setup The setup object
	 */
	function createSecurityRules( required setup ){
		securityRuleService.resetRules();
	}

	/**
	 * Process ORM Update
	 * @setup The setup object
	 */
	function processORMUpdate( required setup ){
		var appCFCPath = appPath & "Application.cfc";
		var c          = fileRead( appCFCPath );

		c = replaceNoCase( c, """update""", """none""" );
		fileWrite( appCFCPath, c );
		return this;
	}

	/**
	 * Process ColdBox Passwords
	 * @setup The setup object
	 */
	function processColdBoxPasswords( required setup ){
		var configPath = appPath & "config/Coldbox.cfc";
		var c          = fileRead( configPath );
		var newPass    = hash( now() & setup.getUserData().toString(), "MD5" );
		c              = replaceNoCase( c, "@fwPassword@", newPass, "all" );
		fileWrite( configPath, c );
		coldbox.setSetting( "debugPassword", newpass );
		coldbox.setSetting( "reinitPassword", newpass );

		return this;
	}

	/**
	 * Process Rewrite Scripts
	 * @setup The setup object
	 */
	function processRewrite( required setup ){
		// rewrite on Router
		var routesPath = appPath & "config/Router.cfc";
		var c          = fileRead( routesPath );
		c              = replaceNoCase( c, "setFullRewrites( false )", "setFullRewrites( true )" );
		fileWrite( routesPath, c );

		// determine engine and setup the appropriate file for the rewrite engine
		switch ( arguments.setup.getRewrite_Engine() ) {
			case "mod_rewrite": {
				// do nothing, .htaccess already on root
				break;
			}
			case "contentbox_express":
			case "commandbox": {
				// do nothing, tuckey already setup at the servlet level on both commandbox and express.
				break;
			}
			case "iis7": {
				var webConfigPath = getDirectoryFromPath( getMetadata( this ).path ) & "web.config";
				// move web.config to root
				fileCopy( webConfigPath, appPath & "web.config" );
				break;
			}
		}

		return this;
	}

	/**
	 * Create permissions
	 * @setup The setup object
	 */
	function createPermissions( required setup ){
		var perms = {
			"SYSTEM_TAB" : "Access to the ContentBox System tools",
			"SYSTEM_SAVE_CONFIGURATION" : "Ability to update global configuration data",
			"SYSTEM_RAW_SETTINGS" : "Access to the ContentBox raw geek settings panel",
			"SYSTEM_AUTH_LOGS" : "Access to the system auth logs",
			"TOOLS_IMPORT" : "Ability to import data into ContentBox",
			"ROLES_ADMIN" : "Ability to manage roles, default is view only",
			"PERMISSIONS_ADMIN" : "Ability to manage permissions, default is view only",
			"AUTHOR_ADMIN" : "Ability to manage authors, default is view only",
			"WIDGET_ADMIN" : "Ability to manage widgets, default is view only",
			"THEME_ADMIN" : "Ability to manage layouts, default is view only",
			"COMMENTS_ADMIN" : "Ability to manage comments, default is view only",
			"CONTENTSTORE_ADMIN" : "Ability to manage the content store, default is view only",
			"PAGES_ADMIN" : "Ability to manage content pages, default is view only",
			"PAGES_EDITOR" : "Ability to manage content pages but not publish pages",
			"CATEGORIES_ADMIN" : "Ability to manage categories, default is view only",
			"ENTRIES_ADMIN" : "Ability to manage blog entries, default is view only",
			"ENTRIES_EDITOR" : "Ability to manage blog entries but not publish entries",
			"RELOAD_MODULES" : "Ability to reload modules",
			"SECURITYRULES_ADMIN" : "Ability to manage the system's security rules, default is view only",
			"GLOBALHTML_ADMIN" : "Ability to manage the system's global HTML content used on layouts",
			"MEDIAMANAGER_ADMIN" : "Ability to manage the system's media manager",
			"VERSIONS_ROLLBACK" : "Ability to rollback content versions",
			"VERSIONS_DELETE" : "Ability to delete past content versions",
			"SYSTEM_UPDATES" : "Ability to view and apply ContentBox updates",
			"MODULES_ADMIN" : "Ability to manage ContentBox Modules",
			"CONTENTBOX_ADMIN" : "Access to the enter the ContentBox administrator console",
			"FORGEBOX_ADMIN" : "Ability to manage ForgeBox installations and connectivity.",
			"EDITORS_DISPLAY_OPTIONS" : "Ability to view the content display options panel",
			"EDITORS_RELATED_CONTENT" : "Ability to view the related content panel",
			"EDITORS_MODIFIERS" : "Ability to view the content modifiers panel",
			"EDITORS_CACHING" : "Ability to view the content caching panel",
			"EDITORS_CATEGORIES" : "Ability to view the content categories panel",
			"EDITORS_HTML_ATTRIBUTES" : "Ability to view the content HTML attributes panel",
			"EDITORS_EDITOR_SELECTOR" : "Ability to change the editor to another registered online editor",
			"TOOLS_EXPORT" : "Ability to export data from ContentBox",
			"CONTENTSTORE_EDITOR" : "Ability to manage content store elements but not publish them",
			"MEDIAMANAGER_LIBRARY_SWITCHER" : "Ability to switch media manager libraries for management",
			"EDITORS_CUSTOM_FIELDS" : "Ability to manage custom fields in any content editors",
			"GLOBAL_SEARCH" : "Ability to do global searches in the ContentBox Admin",
			"EDITORS_LINKED_CONTENT" : "Ability to view the linked content panel",
			"MENUS_ADMIN" : "Ability to manage the menu builder",
			"EDITORS_FEATURED_IMAGE" : "Ability to view the featured image panel",
			"EMAIL_TEMPLATE_ADMIN" : "Ability to admin and preview email templates"
		};

		var allperms = [];
		for ( var key in perms ) {
			var props          = { permission : key, description : perms[ key ] };
			permissions[ key ] = permissionService.new( properties = props );
			arrayAppend( allPerms, permissions[ key ] );
		}
		permissionService.saveAll( entities = allPerms, transactional = false );

		return this;
	}

	/**
	 * Create roles and return the admin
	 * @setup The setup object
	 */
	function createRoles( required setup ){
		// Create Permissions
		createPermissions( arguments.setup );

		// Create Editor
		var oRole = roleService.new( properties = { role : "Editor", description : "A ContentBox editor" } );
		// Add Editor Permissions
		oRole.addPermission( permissions[ "COMMENTS_ADMIN" ] );
		oRole.addPermission( permissions[ "CONTENTSTORE_EDITOR" ] );
		oRole.addPermission( permissions[ "PAGES_EDITOR" ] );
		oRole.addPermission( permissions[ "CATEGORIES_ADMIN" ] );
		oRole.addPermission( permissions[ "ENTRIES_EDITOR" ] );
		oRole.addPermission( permissions[ "THEME_ADMIN" ] );
		oRole.addPermission( permissions[ "GLOBALHTML_ADMIN" ] );
		oRole.addPermission( permissions[ "MEDIAMANAGER_ADMIN" ] );
		oRole.addPermission( permissions[ "VERSIONS_ROLLBACK" ] );
		oRole.addPermission( permissions[ "CONTENTBOX_ADMIN" ] );
		oRole.addPermission( permissions[ "EDITORS_LINKED_CONTENT" ] );
		oRole.addPermission( permissions[ "EDITORS_DISPLAY_OPTIONS" ] );
		oRole.addPermission( permissions[ "EDITORS_RELATED_CONTENT" ] );
		oRole.addPermission( permissions[ "EDITORS_MODIFIERS" ] );
		oRole.addPermission( permissions[ "EDITORS_CACHING" ] );
		oRole.addPermission( permissions[ "EDITORS_CATEGORIES" ] );
		oRole.addPermission( permissions[ "EDITORS_HTML_ATTRIBUTES" ] );
		oRole.addPermission( permissions[ "EDITORS_EDITOR_SELECTOR" ] );
		oRole.addPermission( permissions[ "EDITORS_CUSTOM_FIELDS" ] );
		oRole.addPermission( permissions[ "GLOBAL_SEARCH" ] );
		oRole.addPermission( permissions[ "MENUS_ADMIN" ] );
		oRole.addPermission( permissions[ "EDITORS_FEATURED_IMAGE" ] );
		oRole.addPermission( permissions[ "EMAIL_TEMPLATE_ADMIN" ] );
		roleService.save( entity = oRole, transactional = false );

		// Create Admin
		var oRole = roleService.new(
			properties = { role : "Administrator", description : "A ContentBox Administrator" }
		);
		// Add All Permissions To Admin
		for ( var key in permissions ) {
			oRole.addPermission( permissions[ key ] );
		}
		roleService.save( entity = oRole, transactional = false );

		return oRole;
	}

	/**
	 * Create author
	 * @setup The setup object
	 * @adminRole The role of the admin string
	 */
	function createAuthor( required setup, required adminRole ){
		var oAuthor = authorService.new( properties = arguments.setup.getUserData() );
		oAuthor.setIsActive( true );
		oAuthor.setRole( adminRole );
		authorService.saveAuthor( oAuthor );

		return oAuthor;
	}

	/**
	 * Create Sample Data
	 */
	function createSampleData( required setup, required author ){
		// create a few categories
		categoryService.createCategories( "News, ColdFusion, ColdBox, ContentBox" );

		// create some blog entries
		var entry = entryService.new(
			properties = {
				title              : "My first entry",
				slug               : "my-first-entry",
				publishedDate      : now(),
				isPublished        : true,
				allowComments      : true,
				passwordProtection : "",
				HTMLKeywords       : "cool,first entry, contentbox",
				HTMLDescription    : "The most amazing ContentBox blog entry in the world"
			}
		);
		entry.setCreator( author );
		// version content
		entry.addNewContentVersion(
			content   = "Hey everybody, this is my first blog entry made from ContentBox.  Isn't this amazing!'",
			changelog = "Initial creation",
			author    = author
		);

		// good comment
		var comment = commentService.new(
			properties = {
				content     : "What an amazing blog entry, congratulations!",
				author      : "Awesome Joe",
				authorIP    : cgi.REMOTE_ADDR,
				authorEmail : "awesomejoe@contentbox.org",
				authorURL   : "www.ortussolutions.com",
				isApproved  : true
			}
		);
		comment.setRelatedContent( entry );
		entry.addComment( comment );

		// nasty comment
		var comment = commentService.new(
			properties = {
				content     : "I am some bad words and bad comment not approved",
				author      : "Bad Joe",
				authorIP    : cgi.REMOTE_ADDR,
				authorEmail : "badjoe@contentbox.org",
				authorURL   : "www.ortussolutions.com",
				isApproved  : false
			}
		);
		comment.setRelatedContent( entry );
		entry.addComment( comment );

		// save entry
		entryService.saveEntry( entry );

		// create a page
		var page = pageService.new(
			properties = {
				title              : "About",
				slug               : "about",
				publishedDate      : now(),
				isPublished        : true,
				allowComments      : false,
				passwordProtection : "",
				HTMLKeywords       : "about, contentbox,coldfusion,coldbox",
				HTMLDescription    : "The most amazing ContentBox page in the world",
				layout             : "pages"
			}
		);
		page.setCreator( author );
		// Add new version
		page.addNewContentVersion(
			content   = "<p>Hey welcome to my about page for ContentBox, isn't this great!</p><p>{{{ContentStore slug='contentbox'}}}</p>",
			changelog = "First creation",
			author    = author
		);
		pageService.savePage( page );

		// create a custom store element
		var contentStore = contentStoreService.new(
			properties = {
				title              : "Contact Info",
				slug               : "contentbox",
				publishedDate      : now(),
				isPublished        : true,
				allowComments      : false,
				passwordProtection : "",
				description        : "Our contact information"
			}
		);
		contentStore.setCreator( author );
		contentStore.addNewContentVersion(
			content = "<p style=""text-align: center;"">
	<a href=""https://www.ortussolutions.com/products/contentbox""><img alt="""" src=""/index.cfm/__media/ContentBox_300.png"" /></a></p>
<p style=""text-align: center;"">
	Created by <a href=""https://www.ortussolutions.com"">Ortus Solutions, Corp</a> and powered by <a href=""http://coldbox.org"">ColdBox Platform</a>.</p>",
			changelog = "First creation",
			author    = author
		);
		contentStoreService.saveContent( contentStore );
	}

}
