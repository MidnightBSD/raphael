/*
 Copyright (C) 2018 Christian Dywan <christian@twotoasts.de>

 This library is free software; you can redistribute it and/or
 modify it under the terms of the GNU Lesser General Public
 License as published by the Free Software Foundation; either
 version 2.1 of the License, or (at your option) any later version.

 See the file COPYING for the full license text.
*/

class UrlbarTest {
    public static void test_magic_uri () {
        var urlbar = new Raphael.Urlbar ();

        // IPv4
        assert_true (urlbar.magic_uri ("1.2.3.4") == "http://1.2.3.4");
        assert_true (urlbar.magic_uri ("1.2.3.4:8080") == "http://1.2.3.4:8080");
        
        // IPv6
        assert_true (urlbar.magic_uri ("::1") == "http://[::1]");
        assert_true (urlbar.magic_uri ("2001:db8::1") == "http://[2001:db8::1]");
        assert_true (urlbar.magic_uri ("[::1]:8080") == "http://[::1]:8080");
        
        // Already bracketed IPv6 (treated as a normal location)
        assert_true (urlbar.magic_uri ("http://[::1]") == "http://[::1]");
        
        // Localhost
        assert_true (urlbar.magic_uri ("localhost") == "http://localhost");
        assert_true (urlbar.magic_uri ("localhost:8080") == "http://localhost:8080");
        
        // Normal URI
        assert_true (urlbar.magic_uri ("http://example.com") == "http://example.com");
        
        // Search
        assert_true (urlbar.magic_uri ("search term") == null);
        assert_true (urlbar.magic_uri (" google.com") == null);
        
        // Empty
        assert_true (urlbar.magic_uri ("") == "about:blank");
    }

    public static void test_is_ip_address () {
        var urlbar = new Raphael.Urlbar ();

        assert_false (urlbar.is_ip_address (""));
        assert_true (urlbar.is_ip_address ("1.2.3.4"));
        assert_true (urlbar.is_ip_address ("1.2.3.4:8080"));
        assert_true (urlbar.is_ip_address ("user:pass@1.2.3.4"));
        assert_true (urlbar.is_ip_address ("::1"));
        assert_true (urlbar.is_ip_address ("2001:db8::1"));
        assert_true (urlbar.is_ip_address ("[::1]:8080"));
        
        // Not IP addresses
        assert_false (urlbar.is_ip_address ("example.com"));
        assert_false (urlbar.is_ip_address ("example.com:8080"));
        assert_false (urlbar.is_ip_address ("localhost:8080"));
        assert_false (urlbar.is_ip_address ("http://example.com"));
    }
}

void main (string[] args) {
    // We need to initialize GTK for Urlbar which is a Gtk.Entry
    Gtk.init (ref args);
    Test.init (ref args);
    Test.add_func ("/urlbar/magic_uri", UrlbarTest.test_magic_uri);
    Test.add_func ("/urlbar/is_ip_address", UrlbarTest.test_is_ip_address);
    Test.run ();
}
