/*
 Copyright (C) 2018 Christian Dywan <christian@twotoats.de>

 This library is free software; you can redistribute it and/or
 modify it under the terms of the GNU Lesser General Public
 License as published by the Free Software Foundation; either
 version 2.1 of the License, or (at your option) any later version.

 See the file COPYING for the full license text.
*/

namespace Raphael {
    [GtkTemplate (ui = "/ui/navigationbar.ui")]
    public class Navigationbar : Gtk.ActionBar {
        [GtkChild]
        public unowned Gtk.Box actionbox;
        [GtkChild]
        public unowned Gtk.Button go_back;
        [GtkChild]
        public unowned Gtk.Button go_forward;
        [GtkChild]
        public unowned Gtk.Button reload;
        [GtkChild]
        public unowned Gtk.Button stop_loading;
        [GtkChild]
        public unowned Gtk.Button homepage;
        [GtkChild]
        public unowned Urlbar urlbar;
        [GtkChild]
        public unowned Gtk.Button restore;

        construct {
            var settings = CoreSettings.get_default ();
            homepage.visible = settings.homepage_in_toolbar;
            settings.bind_property ("homepage-in-toolbar", homepage, "visible");
        }
    }
}
