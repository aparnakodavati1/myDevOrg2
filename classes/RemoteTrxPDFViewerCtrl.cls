public without sharing class RemoteTrxPDFViewerCtrl {
    public String transactionId {get; set;}
    public String trackingNumber {get; set;}
    public String ipAddress {get; set;}
    public String status {get; set;}
    public String customerLastName {get; set;}
    public String customerFirstName {get; set;}
    public String contactPhone {get; set;}
    public String rejectReason {get; set;}
    public List<RemoteTrxDocumentWrapper> documents {get; set;}
    
    public class RemoteTrxWrapper{
        @AuraEnabled
        public string status {get;set;}
        @AuraEnabled
        public string rejectReason {get;set;}
        @AuraEnabled
        public boolean isExpired {get;set;}
        @AuraEnabled
        public string contactPhone {get;set;}
        @AuraEnabled
        public string requestType {get;set;}
        @AuraEnabled
        public string subStatus {get;set;}
        @AuraEnabled
        public string trackingNumber {get;set;}

    }
    
    public class RemoteTrxDocumentWrapper{
        @AuraEnabled
        public string documentId {get;set;}
        @AuraEnabled
        public string jwtToken {get;set;}
    }

    
    @AuraEnabled
    public static void updateTransactionStatus(String status, String recordId, String ipAddress, 
                                               String rejectReason, String rejectDetails){
    	String currentTrx = RemoteTrxUtil.decrypt(recordId, Label.Remote_Trx_Encryption_Key).toString();
        Remote_Transaction__c trx = [Select Id, Status__c,Type__c,Sub_Status__c, IP_Address__c, Reject_Reason__c, 
                                     Reject_Details__c,RecordTypeId,Request_Accepted_Rejected_On__c 
									 from Remote_Transaction__c where Id = :currentTrx];
        trx.Status__c = status;
        trx.IP_Address__c = ipAddress;
        trx.Request_Accepted_Rejected_On__c = System.now();
        if (status == RemoteTrxUtil.REJECTED) {
           trx.Reject_Reason__c = rejectReason;
           trx.Reject_Details__c = rejectDetails;
        }else if(status == RemoteTrxUtil.ACCEPTED && trx.Type__c == RemoteTrxUtil.REQUEST_TYPE_DOCUMENT ){
            trx.Status__c = status;
            trx.Sub_Status__c = RemoteTrxUtil.getSubStatus(trx.Type__c, RemoteTrxUtil.ACCEPTED); 
           trx.RecordTypeId = Schema.SObjectType.Remote_Transaction__c.getRecordTypeInfosByName().get(RemoteTrxUtil.RECORD_TYPE_ACCEPTED_DOCUMENT).getRecordTypeId();
        }else if(status == RemoteTrxUtil.ACCEPTED && trx.Type__c == RemoteTrxUtil.REQUEST_TYPE_BOTH ){
           trx.Status__c = RemoteTrxUtil.VIEWED;
           trx.Sub_Status__c = RemoteTrxUtil.SIGNED_DOCUMENT_PENDING_PAYMENT;
        }
        
        try{
           update trx;
        }catch(Exception ex){
           System.debug(LoggingLevel.ERROR, 'RemoteTrxPDFViewerCtrl -> updateTransactionStatus ' + ex);
           ExceptionHandling.addException(ex, 'RemoteTransaction - RemoteTrxPDFViewerCtrl', 'updateTransactionStatus');
        }
                                                   
    }
    
    @AuraEnabled
    public static RemoteTrxWrapper getFromServer (String recordId) {
        String currentTrxId = RemoteTrxUtil.decrypt(recordId, Label.Remote_Trx_Encryption_Key).toString();
        Remote_Transaction__c trx = [Select Id,Name,Type__c, Status__c,Sub_Status__c, 
                                     Reject_Reason__c, Is_Expired__c,Customer_Viewed_On__c, 
                                     Contact_Phone__c from Remote_Transaction__c where Id = :currentTrxId];
        if(trx.Status__c == RemoteTrxUtil.SENT){
            trx.Status__c = RemoteTrxUtil.VIEWED;
            if(trx.Sub_Status__c != RemoteTrxUtil.SIGNED_DOCUMENT_PENDING_PAYMENT){
                trx.Sub_Status__c = RemoteTrxUtil.getSubStatus(trx.Type__c, RemoteTrxUtil.VIEWED);
            }
            trx.Customer_Viewed_On__c = System.now();
            try{
                update trx;
            }catch(Exception ex){
                System.debug(LoggingLevel.ERROR, 'RemoteTrxPDFViewerCtrl -> getFromServer ' + ex);
                ExceptionHandling.addException(ex, 'RemoteTransaction - RemoteTrxPDFViewerCtrl', 'getFromServer');
            }
        }
        
        RemoteTrxWrapper instance = new RemoteTrxWrapper();
        instance.status = trx.Status__c;
        instance.rejectReason = trx.Reject_Reason__c;
        instance.isExpired = trx.Is_Expired__c ;
        instance.contactPhone = trx.Contact_Phone__c;
        instance.requestType = trx.Type__c;
        instance.subStatus = trx.Sub_Status__c;
        instance.trackingNumber = trx.Name;
        return instance;
    }
    
    public RemoteTrxPDFViewerCtrl() {
        String requestParam = System.currentPagereference().getParameters().get('currentTrx');
        String currentTrxId = RemoteTrxUtil.decrypt(requestParam, Label.Remote_Trx_Encryption_Key).toString();
        Remote_Transaction__c trx = [SELECT Name, Lead_Number__c, Status__c, Customer_Last_Name__c, Customer_Name__c, Contact_Phone__c, Reject_Reason__c FROM Remote_Transaction__c WHERE Id = :currentTrxId][0];
        transactionId = trx.Name;
        trackingNumber = trx.Lead_Number__c;
        status = trx.Status__c;
        customerLastName = trx.Customer_Last_Name__c;
        customerFirstName = trx.Customer_Name__c;
        contactPhone = trx.Contact_Phone__c;
        rejectReason = trx.Reject_Reason__c;
        List<ContentDocumentLink> documentLinks = [SELECT Id, ContentDocumentId, LinkedEntityId, SystemModstamp 
                                               FROM ContentDocumentLink WHERE LinkedEntityId = :currentTrxId ORDER BY SystemModstamp];
        ipAddress = getIPAddress();
        documents = new List<RemoteTrxDocumentWrapper>();
        for (ContentDocumentLink documentLink : documentLinks) {
            RemoteTrxDocumentWrapper document = new RemoteTrxDocumentWrapper();
            document.documentId = documentLink.ContentDocumentId;
            document.jwtToken = generateJWTToken(document.documentId);
            documents.add(document);
        }
    }
    
    private String getIPAddress(){
        String ipAddress = ApexPages.currentPage().getHeaders().get('True-Client-IP');
        // X-Salesforce-SIP has the value when no caching integration or via secure URL.
        if (ipAddress == '' || ipAddress == null) {
            ipAddress = ApexPages.currentPage().getHeaders().get('X-Salesforce-SIP');
        } 
        
        // get IP address when no caching (sandbox, dev, secure urls)        
        if (ipAddress == '' || ipAddress == null) {
            ipAddress = ApexPages.currentPage().getHeaders().get('X-Forwarded-For');
        }
        return ipAddress;
    }
    
    public String generateJWTToken(String documentId){
        String header = '{"alg":"RS256","typ":"JWT"}';
        Long exp = ((dateTime.now().getTime()/1000)+1 + Integer.valueOf(Label.Remote_Trx_JWT_Expiration));
        String payload = '{"document_id":"'+documentId+'","exp":'+exp+',"permissions":"all"}';
        String key = Label.PSPDFKit_JWT_Private_Key;
        
        String header64 = EncodingUtil.base64Encode(Blob.valueOf(header));
        
        header64 = header64.replaceAll('=','');
        header64 = header64.replaceAll('-','');
        header64 = header64.replaceAll('/','');
        
        String payload64 = EncodingUtil.base64Encode(Blob.valueOf(payload));
        
        payload64 = payload64.replaceAll('=','');
        payload64 = payload64.replaceAll('-','');
        payload64 = payload64.replaceAll('/','');
        
        Blob hmacData = Crypto.sign('RSA-SHA256', Blob.valueOf(header64 + '.' + payload64), EncodingUtil.base64Decode(key));
        String signature = EncodingUtil.base64Encode(hmacData);
        String token = header64 + '.' + payload64 + '.' + signature;
        return token;
    }
}