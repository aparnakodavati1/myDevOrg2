public with sharing class RemoteTrxContractLookup {
    
	public static final Map<String, String> lookupRequestReplacementStrings = new Map<String, String> { 
        'SFILEADLOOKUPWS_Input' => 'SFILEADLOOKUPGENERIC_Input', 
            'ListOfSfileadbows_Request' => 'ListOfSfileadlookupbows',
            'Sfileadheaderws_Request' => 'Sfileadlookupheader',
            'OrderNumber' => 'Searchspec'                
            };
                
     // Replacement strings in contract response
    public static final Map<String, String> lookupResponseReplacementStrings = new Map<String, String> {
         'SFILEADLOOKUPGENERIC_Output' => 'SFILEADLOOKUPWS_Output',
         'ListOfSfileadlookupbows' => 'ListOfSfileadbows_Response',
         'Sfileadlookupheader' => 'Sfileadheaderws_Response1',
         'ListOfSfipaymentsws' =>'ListOfSfipaymentws',
         'Sfipaymentsws' => 'Sfipaymentws'
    };
    
    public static final Siebel_Integration_Setting__mdt INTEGRATION_SETTING = [SELECT ID, Client_ID__c,Lead_Upload_Endpoint__c ,
                                                                                Token_Endpoint__c ,Authorization__c, Endpoint_Timeout__c
                                                                                FROM Siebel_Integration_Setting__mdt
                                                                                WHERE MasterLabel = 'GenericContractLookup'];
    
    @InvocableMethod
    public static List<FlowOutput> getContractDetails(List<FlowInputs> request) {
        FlowInputs flowInput = request[0];
        List<FlowOutput> output = new List<FlowOutput>();
        if(String.isBlank(flowInput.leadNumber)){
            return output;
        }
        Opportunity consultation = getConsultationDetails(flowInput);
        if(consultation == null && !flowInput.isServiceProvider){
            return output;//HDIS user does not have access to the Lead
        }else if(flowInput.isServiceProvider || consultation != null){//HDIS and SP do contract lookup
            FlowOutput response = doContractLookup(flowInput);
            response.isTextConsentAvailable = (consultation != null) ? consultation.Text_Consent__c : false;
			response.liveTextNumber = (consultation != null) ? consultation.LiveText_Number__c : null;
			response.customerPhoneNumber = (consultation != null) ? consultation.Text_Phone__c : null;
            response.opportunityId = (consultation != null) ? consultation.ID : null;
            output.add(response);
        }
        return output;
    }
    
    
    public static Opportunity getConsultationDetails(FlowInputs flowInput){
        list<OpportunityLineItem> OpportunityLineItem = [Select Id, OpportunityId from OpportunityLineItem where Opportunity.StageName='Consultation Completed, Sale' AND (Siebel_Lead_Number__c=:flowInput.leadNumber OR (Opportunity.Siebel_Lead_Number__c=:flowInput.leadNumber AND Opportunity.Service_Provider__c = :flowInput.MVendorNumber))];
        List<Opportunity> consultations = new list<Opportunity>();
        if(OpportunityLineItem!=NULL && OpportunityLineItem.size()>0){
            consultations = [SELECT ID,Text_Consent__c, LiveText_Number__c, Text_Phone__c 
                                           FROM Opportunity 
                                           WHERE Id=:OpportunityLineItem[0].OpportunityId];
        }
        return consultations.size() > 0 ? consultations[0] : null ;
    }
    
    public static String getApigeeAuthenticationToken() {
        Http http = new Http();
        HttpRequest request = new HttpRequest();
        HttpResponse response;
        request.setMethod(SyncLogConstant.METHOD_GET);
        //request.setTimeout(Integer.valueOf(INTEGRATION_SETTING.Endpoint_Timeout__c));
        try{
            if (!Test.isRunningTest()) {
                request.setEndpoint(INTEGRATION_SETTING.Token_Endpoint__c);
                request.setHeader(SyncLogConstant.HEADER_AUTHORIZATION,INTEGRATION_SETTING.Authorization__c);
                response = http.send(request);
            }
            if (response <> NULL){
                Map<String,String> responseMap = (Map<String,String>) JSON.deserialize(response.getBody(),Map<String,String>.class);
                return responseMap.get('access_token');
            }
        }catch(Exception ex){
            System.debug(LoggingLevel.ERROR, 'RemoteTrxContractLookup -> getApigeeAuthenticationToken ' + ex);
            ExceptionHandling.addException(ex, 'RemoteTransaction - RemoteTrxContractLookup', 'getApigeeAuthenticationToken');
        }
        return '';
    }
    
    
    public static FlowOutput doContractLookup(FlowInputs flowInput){
        ContractLookupSiebel contractLookup = new ContractLookupSiebel();
        String jsonBody = '';
        FlowOutput output = new FlowOutput();
        ContractLookupSiebel.lookupRequestBody reqBody = new ContractLookupSiebel.lookupRequestBody();
        reqBody.ListOfSfileadbows_Request = new ContractLookupSiebel.ListOfSfileadbows_Request();
        reqBody.ListOfSfileadbows_Request.Sfileadheaderws_Request = new ContractLookupSiebel.Sfileadheaderws_Request();
        reqBody.PageSize = '10';
        reqBody.StartRowNum = '0';
        try{
            //"([Order Number] ='1-7138556271' AND [SFI MVendor #] ='50000209')"
            String queryString = '([Order Number] ='+'\''+flowInput.leadNumber+'\'';
            queryString = String.isNotBlank(flowInput.MVendorNumber) ? 
                queryString+'AND [SFI MVendor #] ='+'\''+flowInput.MVendorNumber+'\''+')' 
                : queryString+')';
            reqBody.ListOfSfileadbows_Request.Sfileadheaderws_Request.OrderNumber = queryString;
            jsonBody = JSON.serialize(reqBody);
            System.debug('jsonBody >>' +jsonBody);
            for (String str : lookupRequestReplacementStrings.keyset()) {
                jsonBody = jsonBody.replace(str,lookupRequestReplacementStrings.get(str));
            }
            String accessToken = getApigeeAuthenticationToken();
            jsonBody = Json.serialize(Json.deserializeUntyped('{"SFILEADLOOKUPGENERIC_Input" : ' + jsonBody + SyncLogCallout.SIEBEL_JSON_SUFFIX_CONTRACT_LOOKUP));
            Http http = new Http();
            HttpRequest request = new HttpRequest();
            request.setEndpoint(INTEGRATION_SETTING.Lead_Upload_Endpoint__c);
            request.setMethod(SyncLogConstant.METHOD_POST);
            request.setHeader(SyncLogConstant.HEADER_CONTENT_TYPE, SyncLogConstant.CONTENT_TYPE_JSON);
            request.setHeader(SyncLogConstant.HEADER_CLIENT_ID, INTEGRATION_SETTING.Client_ID__c);
            request.setHeader(SyncLogConstant.HEADER_APPTOKEN, accessToken);
            request.setBody(jsonBody);
            HttpResponse res = http.send(request);
            String response = res.getBody();
            for (String str : lookupResponseReplacementStrings.keyset()) {
                response = response.replace(str, lookupResponseReplacementStrings.get(str));
            }
            system.debug('response -->' +response);
            ContractLookupSiebel.contractLookupResponse contractDetails = (ContractLookupSiebel.contractLookupResponse) Json.deserialize(response, ContractLookupSiebel.contractLookupResponse.class);
            ContractLookupSiebel.Sfileadheaderws_Response headerResponse = contractDetails.SFILEADLOOKUPWS_Output.ListOfSfileadbows_Response.Sfileadheaderws_Response1; 
            if(headerResponse != null){
                if(String.isNotEmpty(headerResponse.SFILeadTotal)){
                    output.contractAmount = Decimal.valueOf(headerResponse.SFILeadTotal);
                    output.balanceDue = output.contractAmount - getPaidAmount(headerResponse);
                    output.siebelLeadId = headerResponse.Id;
                    output.storeName = headerResponse.MMSVStoreName;
                    output.storeNumber = headerResponse.MMSVStoreNumber;
                    output.storeZipCode = headerResponse.MMSVStoreZipcode;
                    output.customerFirstName = headerResponse.ContactFirstName;
                    output.customerLastName = headerResponse.ContactLastName;
                    output.customerEmail = headerResponse.MainEmailAddress;
                    output.street = headerResponse.MMSVSiteAddress;
                    output.addressLine1 = headerResponse.MMSVSiteAddressLine2;
                    output.city = headerResponse.MMSVSiteCity;
                    output.state = headerResponse.MMSVSiteState;
                    output.zipCode = headerResponse.MMSVSitePostalCode;
                    output.lob = getLOB(headerResponse.SFIProgramGroupNameUnconstrained);
                } 
            }
            
        }catch(Exception ex){
            System.debug(LoggingLevel.ERROR, 'RemoteTrxContractLookup -> doContractLookup ' + ex);
            ExceptionHandling.addException(ex, 'RemoteTransaction - RemoteTrxContractLookup', 'doContractLookup');
        }
        system.debug('output >>' +output);
        return output;
    }
    
    public static String getLOB(String serviceProgramName){
        return [Select id, Family from Product2 
                where Service_Program__c = :serviceProgramName 
                and Family !='' limit 1].Family;
    }
    
    public static Decimal getPaidAmount(ContractLookupSiebel.Sfileadheaderws_Response headerResponse){
        Decimal paidAmount = 0; 
        try{
            system.debug('headerResponse.ListOfSfipaymentws -->' +headerResponse.ListOfSfipaymentws);
            ContractLookupSiebel.ListOfSfipaymentws paymentList = headerResponse.ListOfSfipaymentws;
            if(paymentList.Sfipaymentws != null){
                for(ContractLookupSiebel.Sfipaymentws payment : paymentList.Sfipaymentws){
                    paidAmount +=  Decimal.valueOf(payment.TotalSalesAmount);
                }
            }
        }catch(Exception ex){
            System.debug(LoggingLevel.ERROR, 'RemoteTrxContractLookup -> getPaidAmount ' + ex);
            ExceptionHandling.addException(ex, 'RemoteTransaction - RemoteTrxContractLookup', 'getPaidAmount');
        }
        
        return paidAmount;
    }
    
    public class FlowInputs{
        @InvocableVariable
        public String leadNumber;
        @InvocableVariable
        public String MVendorNumber;
        @InvocableVariable
        public boolean isServiceProvider;
    }
    
    public class FlowOutput {
        @InvocableVariable
        public String opportunityId;
        @InvocableVariable
        public String storeName;
        @InvocableVariable
        public String storeNumber;
        @InvocableVariable
        public String storeZipCode;
        @InvocableVariable
        public Decimal contractAmount;
		@InvocableVariable
        public Decimal balanceDue;
        @InvocableVariable
        public String siebelLeadId;
        @InvocableVariable
        public Boolean isTextConsentAvailable;
		@InvocableVariable
        public String liveTextNumber;
		@InvocableVariable
        public String customerPhoneNumber;
		@InvocableVariable
        public String customerFirstName;
		@InvocableVariable
        public String customerLastName;
		@InvocableVariable
        public String customerEmail;
        @InvocableVariable
        public String street;
        @InvocableVariable
        public String addressLine1;
        @InvocableVariable
        public String city;
        @InvocableVariable
        public String state;
        @InvocableVariable
        public String zipCode;
        @InvocableVariable
        public String lob;
    }
}