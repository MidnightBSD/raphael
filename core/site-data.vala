namespace Raphael {
    public class SiteDataDialog : Gtk.Dialog {
        Browser browser;
        string hostname;
        Gtk.Box list;
        Gtk.Button clear;
        List<WebKit.WebsiteData> matching = new List<WebKit.WebsiteData> ();

        public SiteDataDialog (Browser browser, string hostname) {
            Object (transient_for: browser, modal: true, use_header_bar: 1,
                    title: _("Site Data"));
            this.browser = browser;
            this.hostname = hostname;

            var content = get_content_area () as Gtk.Box;
            content.margin = 12;
            content.spacing = 8;
            var heading = new Gtk.Label (_("Stored data for %s").printf (hostname));
            heading.xalign = 0;
            heading.show ();
            content.pack_start (heading, false, false, 0);

            list = new Gtk.Box (Gtk.Orientation.VERTICAL, 4);
            list.show ();
            content.pack_start (list, false, false, 0);

            clear = new Gtk.Button.with_label (_("_Clear Site Data"));
            clear.use_underline = true;
            clear.sensitive = false;
            clear.show ();
            clear.clicked.connect (() => { clear_site_data.begin (); });
            content.pack_start (clear, false, false, 0);

            add_button (Gtk.Stock.CLOSE, Gtk.ResponseType.CLOSE);
            response.connect ((response_id) => { destroy (); });
            populate.begin ();
        }

        async void populate () {
            try {
                var types = WebKit.WebsiteDataTypes.COOKIES
                          | WebKit.WebsiteDataTypes.DISK_CACHE
                          | WebKit.WebsiteDataTypes.LOCAL_STORAGE
                          | WebKit.WebsiteDataTypes.SESSION_STORAGE
                          | WebKit.WebsiteDataTypes.WEBSQL_DATABASES
                          | WebKit.WebsiteDataTypes.INDEXEDDB_DATABASES;
                var data = yield browser.web_context.website_data_manager.fetch (types, null);
                foreach (var item in data) {
                    string name = item.get_name ();
                    if (name == hostname || hostname.has_suffix ("." + name)) {
                        matching.append (item);
                        var label = new Gtk.Label (name);
                        label.xalign = 0;
                        label.show ();
                        list.pack_start (label, false, false, 0);
                    }
                }
                if (matching.length () == 0) {
                    var label = new Gtk.Label (_("No stored site data."));
                    label.xalign = 0;
                    label.show ();
                    list.pack_start (label, false, false, 0);
                } else {
                    clear.sensitive = true;
                }
            } catch (Error error) {
                var label = new Gtk.Label (_("Could not inspect site data: %s").printf (error.message));
                label.xalign = 0;
                label.show ();
                list.pack_start (label, false, false, 0);
            }
        }

        async void clear_site_data () {
            try {
                var types = WebKit.WebsiteDataTypes.COOKIES
                          | WebKit.WebsiteDataTypes.DISK_CACHE
                          | WebKit.WebsiteDataTypes.LOCAL_STORAGE
                          | WebKit.WebsiteDataTypes.SESSION_STORAGE
                          | WebKit.WebsiteDataTypes.WEBSQL_DATABASES
                          | WebKit.WebsiteDataTypes.INDEXEDDB_DATABASES;
                yield browser.web_context.website_data_manager.remove (types, matching, null);
                clear.sensitive = false;
                foreach (var child in list.get_children ()) {
                    child.destroy ();
                }
                var label = new Gtk.Label (_("No stored site data."));
                label.xalign = 0;
                label.show ();
                list.pack_start (label, false, false, 0);
                matching = new List<WebKit.WebsiteData> ();
            } catch (Error error) {
                warning ("Failed to clear site data: %s", error.message);
            }
        }
    }
}
