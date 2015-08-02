/*
 * Install this file by adding a line to the protections table like:
 * list group AllUsers centralsettings //Perforce/sdp/JsApi/centralsettings.js
 *
 * You can also use different centralsettings files for different
 * groups of users.  You would need to copy this file to make
 * a unique copy for each group, then modify the protections table.
 * For example:
 * list group Developers centralsettings //Perforce/sdp/JsApi/centralsettings_dev.js
 * list group QA centralsettings //Perforce/sdp/JsApi/centralsettings_qa.js
 */
function settings(key) {
    // placeholder for P4V tabs
    /*
    if (key == "p4v_mainTabs")  {
        return ["p4:///files/jsapi/examples/dashboard.html"];
    }
    */

    // placeholder for P4Admin tabs
    /*
    if (key == "p4admin_mainTabs")  {
        return ["p4:///files/jsapi/examples/dashboard.html"];
    }
    */

    // placeholder for P4Admin alerts
    /*
    if (key == "p4admin_alerts")  {
        return ["p4:///files/jsapi/examples/js/alerts/securityAlert.js"];
    }
    */

    // placeholder for submit dialog
    /*
    if (key == "p4v_submitDialog") {
        return "p4:///files/jsapi/examples/submitNoFramework.html";
    }
    */

    // P4V preferences
    if (key == "p4v_preferences") {
        return "//Perforce/sdp/JsApi/p4vsettings.xml";
    }
} 

// The "settings" function is called periodically
settings(P4JsApi.centralSettingsKey());
