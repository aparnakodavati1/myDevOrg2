({
    checkIfCommunity : function(cmp) {
        var action  = cmp.get("c.isCommunity");
        action.setCallback(this, function(response) {
            var state = response.getState();
            if(state === "SUCCESS") {
                if(response.getReturnValue()){
                    cmp.set("v.isViewedInCommunity", true);
                }
                
            }
        });
        $A.enqueueAction(action);
    },
    navigateToHome : function(cmp) {
        /*if(cmp.get("v.isViewedInCommunity")){
            var urlEvent = $A.get("e.force:navigateToURL");
            urlEvent.setParams({
                "url": "/remotetransaction"
            });
            urlEvent.fire();
        }else{*/
            //Salesforce
            var homeEvt = $A.get("e.force:navigateToObjectHome");
            homeEvt.setParams({
                "scope": "Remote_Transaction__c"
            });
            homeEvt.fire();
       // }
    }
})