({
    doInit : function(component, event, helper) {
        var parsedUrl = new URL(window.location.href);
        component.set('v.currentTrx', encodeURIComponent(parsedUrl.searchParams.get("txid")));
        var vfOrigin = component.get("v.vfHost");
        
        window.addEventListener("message", $A.getCallback(function(event) {
            var message = JSON.parse(event.data);
            if (event.origin !== vfOrigin) {
                // Not the expected origin: Reject the message!
                return;
            }
            if (message.status !== 'Error') {
                helper.updateTrxStatus(component, JSON.parse(event.data));
            } else {
                component.set('v.error', 'IMCOMPLETE');
            }
            
        }), false);
        
        helper.getTrx(component, parsedUrl.searchParams.get("txid"));
    }
})