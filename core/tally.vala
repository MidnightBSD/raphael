/*
 Copyright (C) 2018 Christian Dywan <christian@twotoats.de>

 This library is free software; you can redistribute it and/or
 modify it under the terms of the GNU Lesser General Public
 License as published by the Free Software Foundation; either
 version 2.1 of the License, or (at your option) any later version.

 See the file COPYING for the full license text.
*/

namespace Raphael {
    [GtkTemplate (ui = "/ui/tally.ui")]
    public class Tally : Gtk.Box {
        public Tab tab { get; protected set; }
        public string? uri { get; set; }
        public string? title { get; set; }
        bool _show_close;
        public bool show_close { get { return _show_close; } set {
            _show_close = value;
            update_visibility ();
        } }

        public signal void clicked ();
        // Implement toggled state of Gtk.ToggleButton
        bool _active = false;
        public bool active { get { return _active; } set {
            _active = value;
            if (_active) {
                set_state_flags (Gtk.StateFlags.CHECKED, false);
            } else {
                unset_state_flags (Gtk.StateFlags.CHECKED);
            }
        } }

        SimpleActionGroup? group = null;
        Gtk.CssProvider? color_provider = null;
        uint last_button = 0;

        [GtkChild]
        unowned Gtk.Button body;
        [GtkChild]
        unowned Gtk.Label caption;
        [GtkChild]
        unowned Gtk.Spinner spinner;
        [GtkChild]
        unowned Favicon favicon;
        [GtkChild]
        unowned Gtk.Image audio;
        [GtkChild]
        unowned Gtk.Button close;

        public Tally (Tab tab) {
            Object (tab: tab,
                    uri: tab.display_uri,
                    title: tab.display_title,
                    tooltip_text: tab.display_title,
                    visible: tab.visible);
            favicon.surface = (Cairo.Surface?)tab.favicon;
            tab.notify["favicon"].connect ((pspec) => {
                favicon.surface = (Cairo.Surface?)tab.favicon;
            });
            tab.bind_property ("display-uri", this, "uri");
            title = tab.display_title;
            tab.bind_property ("display-title", this, "title");
            bind_property ("title", this, "tooltip-text");
            tab.bind_property ("visible", this, "visible");
            body.clicked.connect (() => { clicked (); });
            close.clicked.connect (() => { tab.try_close (); });
            tab.notify["color"].connect (apply_color);
            apply_color ();
            tab.notify["is-loading"].connect ((pspec) => {
                favicon.visible = !tab.is_loading;
                spinner.visible = !favicon.visible;
            });
            tab.bind_property ("is-playing-audio", audio, "visible", BindingFlags.SYNC_CREATE);

            // Pinned tab style: icon only
            tab.notify["pinned"].connect ((pspec) => {
                update_visibility ();
            });
            CoreSettings.get_default ().notify["close-buttons-on-tabs"].connect ((pspec) => {
                update_visibility ();
            });

            update_close_position ();
            Gtk.Settings.get_default ().notify["gtk-decoration-layout"].connect ((pspec) => {
                update_close_position ();
            });
        }

        void apply_color () {
            Gdk.RGBA background_color = Gdk.RGBA ();
            Gdk.RGBA foreground_color = Gdk.RGBA ();
            if (tab.color != null) {
                background_color.parse (tab.color);
                // Ensure high contrast by enforcing black/ white foreground based on Y(UV)
                double brightness = 0.299 * background_color.red
                                  + 0.587 * background_color.green
                                  + 0.114 * background_color.blue;
                foreground_color.parse (brightness < 0.5 ? "white" : "black");
                if (color_provider == null) {
                    color_provider = new Gtk.CssProvider ();
                    get_style_context ().add_provider (color_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
                    body.get_style_context ().add_provider (color_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
                    caption.get_style_context ().add_provider (color_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
                    close.get_style_context ().add_provider (color_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
                    audio.get_style_context ().add_provider (color_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
                }
                try {
                    color_provider.load_from_data ("""
                        * {
                          background-color: %s;
                          color: %s;
                        }
                    """.printf (background_color.to_string (), foreground_color.to_string ()));
                } catch (Error error) {
                    warning ("Failed to apply tab color CSS: %s", error.message);
                }
                return;
            }
            if (color_provider != null) {
                try {
                    color_provider.load_from_data ("");
                } catch (Error error) {
                    warning ("Failed to reset tab color CSS: %s", error.message);
                }
            }
        }

        void update_close_position () {
            string layout = Gtk.Settings.get_default ().gtk_decoration_layout;
            var box = (Gtk.Box)body.parent;
            if (layout.index_of ("c") < layout.index_of (":")) {
                box.reorder_child (close, 0);
                box.reorder_child (body, -1);
            } else {
                box.reorder_child (close, -1);
                box.reorder_child (body, 0);
            }
        }

        void update_visibility () {
            caption.visible = !(tab.pinned && _show_close);
            close.visible = !tab.pinned && CoreSettings.get_default ().close_buttons_on_tabs;
        }

        construct {
            bind_property ("title", caption, "label");
            var motion = new Gtk.EventControllerMotion (body);
            motion.propagation_phase = Gtk.PropagationPhase.CAPTURE;
            motion.enter.connect ((x, y) => {
                set_state_flags (Gtk.StateFlags.PRELIGHT, false);
            });
            motion.leave.connect (() => {
                unset_state_flags (Gtk.StateFlags.PRELIGHT);
            });
            var clicks = new Gtk.GestureMultiPress (body);
            clicks.propagation_phase = Gtk.PropagationPhase.CAPTURE;
            clicks.button = 0;
            clicks.pressed.connect ((n_press, x, y) => {
                last_button = clicks.get_current_button ();
                // No context menu for a single tab
                if (!show_close) {
                    return;
                }
                if (last_button == Gdk.BUTTON_SECONDARY) {
                    ((SimpleAction)group.lookup_action ("pin")).set_enabled (!tab.pinned);
                    ((SimpleAction)group.lookup_action ("unpin")).set_enabled (tab.pinned);
                    var app = (App)Application.get_default ();
                    var menu = new Gtk.Popover.from_model (this, app.get_menu_by_id ("tally-menu"));
                    menu.show ();
                }
            });
            clicks.released.connect ((n_press, x, y) => {
                switch (last_button) {
                    case Gdk.BUTTON_PRIMARY:
                        clicked ();
                        break;
                    case Gdk.BUTTON_MIDDLE:
                        tab.try_close ();
                        break;
                }
                last_button = 0;
            });

            group = new SimpleActionGroup ();
            var action = new SimpleAction ("pin", null);
            action.activate.connect (() => {
                tab.pinned = true;
            });
            group.add_action (action);
            action = new SimpleAction ("unpin", null);
            action.activate.connect (() => {
                tab.pinned = false;
            });
            group.add_action (action);
            action = new SimpleAction ("duplicate", null);
            action.activate.connect (() => {
                var browser = (Browser)tab.get_ancestor (typeof (Browser));
                browser.add (new Tab (null, tab.web_context, uri));
            });
            group.add_action (action);
            action = new SimpleAction ("close-other", null);
            action.activate.connect (() => {
                var browser = (Browser)tab.get_ancestor (typeof (Browser));
                foreach (var widget in browser.tabs.get_children ()) {
                    if (widget != tab) {
                        ((Tab)widget).try_close ();
                    }
                }
            });
            group.add_action (action);
            action = new SimpleAction ("close-tab", null);
            action.activate.connect (() => {
                tab.try_close ();
            });
            group.add_action (action);
            insert_action_group ("tally", group);
        }
    }
}
