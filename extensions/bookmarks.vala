/*
 Copyright (C) 2013-2018 Christian Dywan <christian@twotoats.de>

 This library is free software; you can redistribute it and/or
 modify it under the terms of the GNU Lesser General Public
 License as published by the Free Software Foundation; either
 version 2.1 of the License, or (at your option) any later version.

 See the file COPYING for the full license text.
*/

namespace Bookmarks {
    class BookmarksDatabase : Raphael.Database {
        static BookmarksDatabase? _default = null;
        public static BookmarksDatabase get_default () throws Raphael.DatabaseError {
            if (_default == null) {
                _default = new BookmarksDatabase ();
            }
            return _default;
        }

        BookmarksDatabase () throws Raphael.DatabaseError {
            Object (path: "bookmarks.db");
            init ();
        }

        public async override Raphael.DatabaseItem? lookup (string uri) throws Raphael.DatabaseError {
            string sqlcmd = """
                SELECT id, title FROM %s WHERE uri = :uri LIMIT 1
                """.printf (table);
            var statement = prepare (sqlcmd,
                ":uri", typeof (string), uri);
            if (statement.step ()) {
                string title = statement.get_string ("title");
                var item = new Raphael.DatabaseItem (uri, title);
                item.database = this;
                item.id = statement.get_int64 ("id");
                return item;
            }
            return null;
        }

        public async override List<Raphael.DatabaseItem>? query (string? filter=null, int64 max_items=15, Cancellable? cancellable=null) throws Raphael.DatabaseError {
            string where = filter != null ? "WHERE uri LIKE :filter OR title LIKE :filter" : "";
            string sqlcmd = """
                SELECT id, uri, title, visit_count AS ct FROM %s
                %s
                GROUP BY uri
                ORDER BY ct DESC LIMIT :limit
                """.printf (table, where);

            try {
                var statement = prepare (sqlcmd,
                    ":limit", typeof (int64), max_items);
                if (filter != null) {
                    string real_filter = "%" + filter.replace (" ", "%") + "%";
                    statement.bind (":filter", typeof (string), real_filter);
                }

                var items = new List<Raphael.DatabaseItem> ();
                while (statement.step ()) {
                    string uri = statement.get_string ("uri");
                    string title = statement.get_string ("title");
                    var item = new Raphael.DatabaseItem (uri, title);
                    item.database = this;
                    item.id = statement.get_int64 ("id");
                    items.append (item);

                    uint src = Idle.add (query.callback);
                    yield;
                    Source.remove (src);

                    if (cancellable != null && cancellable.is_cancelled ())
                        return null;
                }
                if (cancellable != null && cancellable.is_cancelled ())
                    return null;
                return items;
            } catch (Raphael.DatabaseError error) {
                critical ("Failed to query bookmarks: %s", error.message);
            }
            return null;
        }

        public async override bool update (Raphael.DatabaseItem item) throws Raphael.DatabaseError {
            string sqlcmd = """
                UPDATE %s SET uri = :uri, title = :title WHERE id = :id
                """.printf (table);
            try {
                var statement = prepare (sqlcmd,
                    ":id", typeof (int64), item.id,
                    ":uri", typeof (string), item.uri,
                    ":title", typeof (string), item.title);
                if (statement.exec ()) {
                    return true;
                }
            } catch (Error error) {
                critical ("Failed to update %s: %s", table, error.message);
            }
            return false;
        }

        public async override bool insert (Raphael.DatabaseItem item) throws Raphael.DatabaseError {
            item.database = this;

            string sqlcmd = """
                INSERT INTO %s (uri, title) VALUES (:uri, :title)
                """.printf (table);
            var statement = prepare (sqlcmd,
                ":uri", typeof (string), item.uri,
                ":title", typeof (string), item.title);
            if (statement.exec ()) {
                item.id = statement.row_id ();
                return true;
            }
            return false;
        }
    }

    [GtkTemplate (ui = "/ui/bookmarks-button.ui")]
    public class Button : Gtk.Button {
        [GtkChild]
        unowned Gtk.Popover popover;
        [GtkChild]
        unowned Gtk.Entry entry_title;
        [GtkChild]
        unowned Gtk.Button button_remove;

        Raphael.Browser browser;
        public signal void changed ();

        construct {
            popover.relative_to = this;
            entry_title.changed.connect (() => {
                var item = browser.tab.get_data<Raphael.DatabaseItem?> ("bookmarks-item");
                if (item != null) {
                    item.title = entry_title.text;
                    changed ();
                }
            });
            button_remove.clicked.connect (() => {
                popover.hide ();
                var item = browser.tab.get_data<Raphael.DatabaseItem?> ("bookmarks-item");
                item.delete.begin ();
                browser.tab.set_data<Raphael.DatabaseItem?> ("bookmarks-item", null);
                changed ();
            });
        }

        async Raphael.DatabaseItem item_for_tab (Raphael.Tab tab) {
            var item = tab.get_data<Raphael.DatabaseItem?> ("bookmarks-item");
            if (item == null) {
                try {
                    item = yield BookmarksDatabase.get_default ().lookup (tab.display_uri);
                } catch (Raphael.DatabaseError error) {
                    critical ("Failed to lookup %s in bookmarks database: %s", tab.display_uri, error.message);
                }
                if (item == null) {
                    item = new Raphael.DatabaseItem (tab.display_uri, tab.display_title);
                    try {
                        yield BookmarksDatabase.get_default ().insert (item);
                        changed ();
                    } catch (Raphael.DatabaseError error) {
                        critical ("Failed to add %s to bookmarks database: %s", item.uri, error.message);
                    }
                }
                entry_title.text = item.title;
                tab.set_data<Raphael.DatabaseItem?> ("bookmarks-item", item);
            }
            return item;
        }

        public virtual signal void add_bookmark () {
            var tab = browser.tab;
            item_for_tab.begin (tab);
            popover.show ();
        }

        public Button (Raphael.Browser browser) {
            this.browser = browser;

            var action = new SimpleAction ("bookmark-add", null);
            action.activate.connect (bookmark_add_activated);
            browser.notify["uri"].connect (() => {
                action.set_enabled (browser.uri.has_prefix ("http"));
            });
            browser.add_action (action);
            browser.application.set_accels_for_action ("win.bookmark-add", { "<Primary>d" });
        }

        void bookmark_add_activated () {
            add_bookmark ();
        }
    }

    class Row : Gtk.ListBoxRow {
        public Raphael.DatabaseItem item { get; construct set; }

        public Row (Raphael.DatabaseItem item) {
            Object (item: item);
        }

        construct {
            var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            box.margin = 6;
            box.margin_start = 8;
            box.margin_end = 8;

            var title = new Gtk.Label (item.title ?? item.uri);
            title.halign = Gtk.Align.START;
            title.ellipsize = Pango.EllipsizeMode.END;
            title.xalign = 0.0f;
            box.add (title);

            var uri = new Gtk.Label (item.uri);
            uri.halign = Gtk.Align.START;
            uri.ellipsize = Pango.EllipsizeMode.END;
            uri.xalign = 0.0f;
            uri.opacity = 0.7;
            box.add (uri);

            add (box);
            show_all ();
        }
    }

    class Panel : Gtk.ScrolledWindow {
        Raphael.Browser browser;
        Gtk.ListBox list;

        public Panel (Raphael.Browser browser) {
            Object ();
            this.browser = browser;
        }

        construct {
            list = new Gtk.ListBox ();
            list.selection_mode = Gtk.SelectionMode.BROWSE;
            list.row_activated.connect ((row) => {
                var bookmark = row as Row;
                if (bookmark != null && browser.tab != null) {
                    browser.tab.load_uri (bookmark.item.uri);
                }
            });
            add (list);
            show_all ();
            reload.begin ();
        }

        public async void reload () {
            foreach (var child in list.get_children ()) {
                child.destroy ();
            }

            try {
                var items = yield BookmarksDatabase.get_default ().query (null, 500);
                if (items == null || items.length () == 0) {
                    var empty = new Gtk.Label (_("No bookmarks yet"));
                    empty.margin = 12;
                    empty.wrap = true;
                    empty.show ();
                    list.add (empty);
                    return;
                }

                foreach (var item in items) {
                    list.add (new Row (item));
                }
                list.show_all ();
            } catch (Raphael.DatabaseError error) {
                critical ("Failed to load bookmarks panel: %s", error.message);
            }
        }
    }

    public class Frontend : Object, Raphael.BrowserActivatable {
        public Raphael.Browser browser { owned get; set; }

        public void activate () {
            // No bookmarks in app mode
            if (browser.is_locked) {
                return;
            }

            var panel = new Panel (browser);
            browser.add_panel (panel);
            panel.parent.child_set (panel, "title", _("Bookmarks"));

            var button = new Button (browser);
            button.changed.connect (() => {
                panel.reload.begin ();
            });
            browser.add_button (button);
        }
    }

    public class Completion : Peas.ExtensionBase, Raphael.CompletionActivatable {
        public Raphael.Completion completion { owned get; set; }

        public void activate () {
            try {
                completion.add (BookmarksDatabase.get_default ());
            } catch (Raphael.DatabaseError error) {
                critical ("Failed to add bookmarks completion: %s", error.message);
            }
        }
    }
}

[ModuleInit]
public void peas_register_types(TypeModule module) {
    ((Peas.ObjectModule)module).register_extension_type (
        typeof (Raphael.BrowserActivatable), typeof (Bookmarks.Frontend));
    ((Peas.ObjectModule)module).register_extension_type (
        typeof (Raphael.CompletionActivatable), typeof (Bookmarks.Completion));

}
