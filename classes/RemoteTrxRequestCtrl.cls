public class RemoteTrxRequestCtrl {
    
    @AuraEnabled
    public static boolean deleteDocument(String contentdocumentId){
        Boolean isDeleteSuccess = false;
        try{
            List<ContentDocument> contentDocuments = [Select Id from ContentDocument where ID = :contentdocumentId];
            delete contentDocuments;
            isDeleteSuccess = true;
        }catch (Exception ex){
            System.debug(LoggingLevel.ERROR, 'RemoteTrxFileUploaderCtrl -> deleteDocument ' + ex);
            ExceptionHandling.addException(ex, 'RemoteTransaction - RemoteTrxRequestCtrl', 'deleteDocument');
        }
        return isDeleteSuccess;
    }
    
    @Auraenabled
    public static boolean isCommunity(){
        Id sideId = Site.getSiteId();
        if(sideId != null){
            return true;
        }
        return false;
    }
    
    @AuraEnabled
    public static void deleteRemoteTrx(String transactionId){
        List<Id> documentIds = new List<Id>();
        for(ContentDocumentLink documentLink : [SELECT Id, LinkedEntityId, ContentDocumentId 
                                                FROM ContentDocumentLink 
                                                WHERE LinkedEntityId = :transactionId]){
                                                    documentIds.add(documentLink.ContentDocumentId);
                                                }
        try{
            delete [SELECT Id FROM ContentDocument WHERE ID in :documentIds];
            delete [SELECT Id FROM Remote_Transaction__c WHERE Id = :transactionId];
        }catch(Exception ex){
            System.debug(LoggingLevel.ERROR, 'RemoteTrxFlowFooterCtrl -> deleteRemoteTrx ' + ex); 
            ExceptionHandling.addException(ex, 'RemoteTransaction - RemoteTrxRequestCtrl', 'deleteRemoteTrx');
        }
    }
    
    @AuraEnabled
    public static RemoteTrxFlowHelper.Response uploadDocumentsToPSPDF(String remoteTrxId){
        List<String> transactionIds = new List<String>{remoteTrxId};
        Remote_Transaction__c trx = [SELECT Id, Type__c, Sub_Status__c from Remote_Transaction__c where id =:remoteTrxId];
        if((trx.Type__c == RemoteTrxUtil.REQUEST_TYPE_PAYMENT) || 
			(trx.Type__c == RemoteTrxUtil.REQUEST_TYPE_BOTH && trx.Sub_Status__c == RemoteTrxUtil.SIGNED_DOCUMENT_PENDING_PAYMENT)){
            return null; 
        }
        List<RemoteTrxFlowHelper.Response> responses = RemoteTrxFlowHelper.uploadDocumentsToPSPDF(transactionIds);
        return responses[0];
    }
}