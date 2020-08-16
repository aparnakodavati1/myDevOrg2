({
    init : function(cmp, event, helper) {
        helper.checkIfCommunity(cmp);
        // Figure out which buttons to display
        var availableActions = cmp.get('v.availableActions');
        //alert(availableActions);
        for (var i = 0; i < availableActions.length; i++) {
            if (availableActions[i] == "PAUSE") {
                cmp.set("v.canPause", true);
            } else if (availableActions[i] == "BACK") {
                cmp.set("v.canBack", true);
            } else if (availableActions[i] == "NEXT") {
                cmp.set("v.canNext", true);
            } else if (availableActions[i] == "FINISH") {
                cmp.set("v.canFinish", true);
            }
        }
        debugger;
        var progressIndicator = cmp.find('progressIndicator');
        for (let step of cmp.get('v.stages')) {
            $A.createComponent(
                "lightning:progressStep",
                {
                    "aura:id": "step_" + step,
                    "label": step,
                    "value": step
                },
                function(newProgressStep, status, errorMessage){
                    // Add the new step to the progress array
                    if (status === "SUCCESS") {
                        var body = progressIndicator.get("v.body");
                        body.push(newProgressStep);
                        progressIndicator.set("v.body", body);
                    }
                    else if (status === "INCOMPLETE") {
                        // Show offline error
                        console.log("No response from server, or client is offline.")
                    }
                        else if (status === "ERROR") {
                            // Show error message
                            console.log("Error: " + errorMessage);
                        }
                }
            );
        }
    },
    
    onButtonPressed: function(cmp, event, helper) {
        // Figure out which action was called
        debugger;
        var actionClicked = event.getSource().getLocalId();
        var clickAction = event.getSource().get("v.name");
        if(cmp.get('v.isLastScreen') && clickAction === 'Send'){
            cmp.set('v.isSaveAndSendClicked', true);
        }
        // Fire that action
        var navigate = cmp.get('v.navigateFlow');
        navigate(actionClicked);
    },
    handleCancel: function(cmp, event, helper) {
        debugger;
        var recordId = cmp.get("v.recordId");
        if(!$A.util.isUndefinedOrNull(recordId)){
            var action  = cmp.get("c.deleteRemoteTrx");
            action.setParams({ "transactionId": recordId});
            action.setCallback(this, function(response) {
                var state = response.getState();
                if(state === "SUCCESS") {
                    helper.navigateToHome(cmp);
                }else{
                    //TODO better error handling
                    helper.navigateToHome(cmp);
                }
            });
            $A.enqueueAction(action);
        }else{
            helper.navigateToHome(cmp);
        }
        
    }
})