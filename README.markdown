Overview
========
In the distant past, the Address Book app in Mac OS X Tiger could send mobile SMS messages directly from within the app, if you paired your mobile phone with your Mac via Bluetooth. Along came Leopard, and the feature mysteriously vanished without trace or explanation, and hasn’t reappeared since. Missing the feature, I found a roundabout replacement in the emitSMS dashboard widget. It offers SMS sending via Bluetooth and can also search the Address Book for phone numbers. Having seen that the source code for emitSMS was released, I adapted the backend into a plugin for Address Book.app to provide the missing former functionality.

Usage
-----
The plugin should be compatible with Address Book in Leopard and Snow Leopard. You need to pair your phone with your Mac to use it, with the Bluetooth Setup Assistant. Make sure you allow the Mac to use the phone as a Modem or Serial Port.

After you select a port to use in the pop-up menu, it will test the port for SMS sending capabilities. The port will only be usable if the test succeeds. Some phones seem to be a little flaky when communicating via Bluetooth and require the test to be run a few times before it can establish a connection successfully. If it fails initially, try clicking on the port again.

If ‘Long Messages’ is not enabled your messages will be limited to 160 characters (or 70 characters if you use symbols outside the standard GSM set, e.g. ^ ). Not all phones support the sending of long messages (actually splitting the message into several SMSs). Additionally, not all phones support requesting delivery receipts.

In general, if your phone works with the emitSMS dashboard widget, it should work with this plugin as the same underlying method is used to send the SMSs. 

See [the blog post](http://sigmaris.info/blog/?page_id=60) for more details.

