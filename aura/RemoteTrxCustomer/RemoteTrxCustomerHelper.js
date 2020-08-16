({
    updateTrxStatus : function(component, message) {
        var action  = component.get("c.updateTransactionStatus");
        action.setParams({ "status": message.status, 
                           "recordId": decodeURIComponent(component.get("v.currentTrx")),
                           "ipAddress" : message.ipAddress,
                           "rejectReason": message.rejectReason,
                           "rejectDetails": message.rejectDetails
                         });
        action.setCallback(this, function(response) {
            var state = response.getState();
            if (state === "SUCCESS") {
                if(message.status!='Rejected' && component.get('v.requestType') === 'Both Document and Payment'){
                    location.href = location.href.replace('/acceptdocument?', '/pay?');
                }else{
                	location.href = location.href.replace('/acceptdocument?', '/done?');
                }
            } else if (state === "INCOMPLETE") {
                component.set('v.error', 'INCOMPLETE');
            } else {
                component.set('v.error', 'ERROR');
            }
        });
        $A.enqueueAction(action);
    },
    getTrx : function(component, recordId) {
        var action  = component.get("c.getFromServer");
        action.setParams({ "recordId": recordId });
        action.setCallback(this, function(response) {
            var state = response.getState();
            if (state === "SUCCESS") {
            	var trx = response.getReturnValue();
        		component.set('v.status', trx.status);
        		component.set('v.rejectReason', trx.rejectReason);
        		component.set('v.isExpired', trx.isExpired);
        		component.set('v.contactPhone', formatPhoneNumber(trx.contactPhone));
                component.set('v.requestType', trx.requestType);
                if(trx.requestType === 'Payment' || 
					(trx.requestType === 'Both Document and Payment' && trx.subStatus === 'Signed Document Pending Payment')){
                    location.href = location.href.replace('/acceptdocument?', '/pay?');
                }
            } else {
                component.set('v.error', 'ERROR');
            }
        });
        $A.enqueueAction(action);
        
        function formatPhoneNumber(phoneNumberString) {
            var cleaned = ('' + phoneNumberString).replace(/\D/g, '');
            var match = cleaned.match(/^(1|)?(\d{3})(\d{3})(\d{4})$/);
            if (match) {
                var intlCode = (match[1] ? '+1 ' : '');
                return [intlCode, '', match[2], '-', match[3], '-', match[4]].join('');
            }
            return null;
        }
    }
})