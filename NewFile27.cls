/*Apex Class: NtnxDynamicPicklistCreation
* Author: Vulsala Srinivasulu
* Description: Creates the Field Dependencies from data entered in Deployment Stage records.
* Jira Ticket: BA-79992
*/

public class NtnxDynamicPicklistCreation{

    
    public static MetadataService.MetadataPort createService(){
        
        // getting the user credentials from custom settings
        User_Rest_Service_Cred__c userCred = User_Rest_Service_Cred__c.getInstance(Label.UserRestAPICredName);
        
        // proceed to call api if userCred and updateUsers has records
        Map<String, String> authDetail ;
        if(userCred != null) {
            Blob cryptoKey = EncodingUtil.base64Decode(userCred.Key__c);
            
            Blob decryptedData = Crypto.decryptWithManagedIV('AES256', cryptoKey, EncodingUtil.base64Decode(userCred.Password__c));
            
            //authDetail = NtnxIntegrationUtil.getSessionId(userCred.Login_Domain__c,userCred.UserName__c,decryptedData.toString());
        }
        
        MetadataService.MetadataPort service = new MetadataService.MetadataPort();
        service.SessionHeader = new MetadataService.SessionHeader_element();
        
        if(!test.IsrunningTest() && authDetail!=null){
            service.SessionHeader.sessionId =  authDetail.get('sessionId');
        }
        else{
            service.SessionHeader.sessionId =  userinfo.getsessionId();
        }
        
        return service;
    }
    
      /*Method: createService
    * Author: Vulsala Srinivasulu
    * Description: createOrUpdate the Picklist based on data entered in Deployment Stage records.
    * Jira Ticket: BA-79992
    */
    @future(callout=true)
    public static void createOrUpdatePicklist(Set<Id>setDeployRecordIds, String picklistField, String dependentField){
        
        Map<String, Set<String>> mapControllingValueToDependentValues = new Map<String, Set<String>>();//Stores controlling values to dependent values
        Map<String, Set<String>> mapDependentValueToControllingValues = new Map<String, Set<String>>();//Stores dependent values to controlling values
        Set<String> setDeactivateDependentValues = new Set<String>();//Stores the deactivate Dependent values
        Set<String> setDeactivatePicklistValues = new Set<String>();//Stores the deactivate controlling values
        Map<String, String> mapExistingPickListToNewValue = new Map<String, String>();//Stores the existing to new values.
        Map<String, String> mapDepExistingPickListToNewValue = new Map<String, String>();
        Set<String> setAddPicklistValues = new Set<String>();
        Map<String, String> mapChangeControllingValue = new Map<String, String>();
        
        List<Deployment_Stage__c>listDeploymentStageRecords = [SELECT Id,ObjectApiName__c,NewDependentPicklistValue__c,ExistingControllingPicklistValue__c,ExistingDependentPicklistValue__c,ControllingFieldApiName__c,NewControllingPicklistValue__c,Operation__c,Type__c,DependentFieldApiName__c,DeploymentStatus__c,NewPicklistValue__c,PicklistFieldApiName__c,ExistingPicklistValue__c FROM Deployment_Stage__c WHERE Id IN:setDeployRecordIds OR (IsNewDeployment__c= true AND CreatedDate >:Datetime.now().addSeconds(-60))];
        
        if(listDeploymentStageRecords.IsEmpty()){
            return;
        }
        //Stores the Object Api name
        String objectApiName = listDeploymentStageRecords[0].ObjectApiName__c.trim();
        
        //Check the field Dependency type
        Boolean fieldDependency = listDeploymentStageRecords[0].Type__c=='Field Dependency'?true:false;
        
        List<String> listStringCustomFields = new List<String>();//Stores the custom api names as string.
        
        if(fieldDependency){//if Field Dependency is true
            if(String.IsNotBlank(picklistField)){
                picklistField = objectApiName+'.'+picklistField;//Appends object api and Field Api
                listStringCustomFields.add(picklistField);
            }
            if(String.IsNotBlank(dependentField)){
                dependentField = objectApiName+'.'+dependentField;//Appends object api and Field Api
                listStringCustomFields.add(dependentField);
            }
        }
        else {
            
            picklistField = objectApiName+'.'+picklistField.trim();
            listStringCustomFields.add(picklistField);
        }
        
        MetadataService.MetadataPort MetadataService =  createService();//gets the Metadataservice api session
        
        if(listStringCustomFields.IsEmpty()){return;}
        
        List<MetadataService.CustomField> custoFieldsMetadata = getCustomFieldDetails(MetadataService, listStringCustomFields);//Gets the Custom field details from Metadata service
        
        if(custoFieldsMetadata.IsEmpty()){return;}
        
        MetadataService.CustomField customField;//Stores the Custom Controlling field details
        Map<String,String> mapLabelToPicklistApi;//Stores the Lablel to api values
        system.debug('@@@@@@@@@@@@'+custoFieldsMetadata );
        if(String.IsNotBlank(picklistField)){
            customField = custoFieldsMetadata[0];
            system.debug('@@@@@@@@@@@@'+custoFieldsMetadata[0]);
            mapLabelToPicklistApi = getLabelToPicklistApi(customField);
        }
        
        MetadataService.CustomField depCustomField;//Stores the Custom Dependent field details
        Map<String,String> mapDepLabelToPicklistApi;//Stores the Lablel to api values
        
        if(fieldDependency){//Checks the Field Dependency is true or false
            
            if(String.IsBlank(picklistField) && String.IsNotBlank(dependentField)){
                depCustomField = custoFieldsMetadata[0];
                mapDepLabelToPicklistApi= getLabelToPicklistApi(depCustomField);
            }
            else if(String.IsNotBlank(picklistField) && String.IsNotBlank(dependentField)){
                depCustomField = custoFieldsMetadata[1];
                mapDepLabelToPicklistApi= getLabelToPicklistApi(depCustomField);
            }
        }
        
        for(Deployment_Stage__c DeployRecord : listDeploymentStageRecords){//iterate the list deployment stage records
            
            if(fieldDependency){
                if(mapLabelToPicklistApi!=null && !mapLabelToPicklistApi.IsEmpty() && DeployRecord.ExistingControllingPicklistValue__c!=null && mapLabelToPicklistApi.containsKey(DeployRecord.ExistingControllingPicklistValue__c)){
                    
                    DeployRecord.ExistingControllingPicklistValue__c=mapLabelToPicklistApi.get(DeployRecord.ExistingControllingPicklistValue__c);//Stores the Lable to api values explicity only for incase of label and Api are different 
                }
                
                if(mapDepLabelToPicklistApi!=null && !mapDepLabelToPicklistApi.IsEmpty() && DeployRecord.ExistingDependentPicklistValue__c!=null && mapDepLabelToPicklistApi.containsKey(DeployRecord.ExistingDependentPicklistValue__c)){
                    
                    DeployRecord.ExistingDependentPicklistValue__c=mapDepLabelToPicklistApi.get(DeployRecord.ExistingDependentPicklistValue__c);//Stores the Lable to api values explicity only for incase of label and Api are different
                }
            }
            else{
                if(mapLabelToPicklistApi!=null && !mapLabelToPicklistApi.IsEmpty() && DeployRecord.ExistingPicklistValue__c!=null && mapLabelToPicklistApi.containsKey(DeployRecord.ExistingPicklistValue__c)){
                    
                    DeployRecord.ExistingPicklistValue__c=mapLabelToPicklistApi.get(DeployRecord.ExistingPicklistValue__c);
                }
            }
            
            if(DeployRecord.Operation__c =='Relabel'){
                
                if(fieldDependency){
                    if(DeployRecord.ExistingControllingPicklistValue__c!=null && DeployRecord.NewControllingPicklistValue__c!=null){
                        mapExistingPickListToNewValue.put(DeployRecord.ExistingControllingPicklistValue__c, DeployRecord.NewControllingPicklistValue__c);
                    }
                    
                    if(DeployRecord.ExistingDependentPicklistValue__c!=null && DeployRecord.NewDependentPicklistValue__c!=null){
                        mapDepExistingPickListToNewValue.put(DeployRecord.ExistingDependentPicklistValue__c, DeployRecord.NewDependentPicklistValue__c);
                    }
                }
                else{
                    
                    if(DeployRecord.ExistingPicklistValue__c!=null && DeployRecord.NewPicklistValue__c!=null){
                        mapExistingPickListToNewValue.put(DeployRecord.ExistingPicklistValue__c, DeployRecord.NewPicklistValue__c);
                    }
                }
                
                
            } else if(DeployRecord.Operation__c =='Deactivate'){              
                
                if(fieldDependency){
                    if(DeployRecord.ExistingControllingPicklistValue__c!=null)
                        setDeactivatePicklistValues.add(DeployRecord.ExistingControllingPicklistValue__c.trim());//Stores the Deactivate values
                    
                    if(DeployRecord.ExistingDependentPicklistValue__c!=null)
                        setDeactivateDependentValues.add(DeployRecord.ExistingDependentPicklistValue__c.trim());//Stores the Deactivate values
                }
                else{
                    
                    if(DeployRecord.ExistingPicklistValue__c!=null)
                        setDeactivatePicklistValues.add(DeployRecord.ExistingPicklistValue__c.trim());//Stores the Deactivate values
                }
                
            }
            else if(DeployRecord.Operation__c =='Add' || DeployRecord.Operation__c =='Change Dependency'){
                
                if(fieldDependency){
                    if(mapLabelToPicklistApi!=null && !mapLabelToPicklistApi.IsEmpty() && DeployRecord.NewControllingPicklistValue__c!=null && mapLabelToPicklistApi.containsKey(DeployRecord.NewControllingPicklistValue__c)){
                        DeployRecord.NewControllingPicklistValue__c=mapLabelToPicklistApi.get(DeployRecord.NewControllingPicklistValue__c);
                    }
                    
                    if(mapDepLabelToPicklistApi!=null && !mapDepLabelToPicklistApi.IsEmpty() && DeployRecord.NewDependentPicklistValue__c!=null && mapDepLabelToPicklistApi.containsKey(DeployRecord.NewDependentPicklistValue__c)){
                        DeployRecord.NewDependentPicklistValue__c=mapDepLabelToPicklistApi.get(DeployRecord.NewDependentPicklistValue__c);
                    }
                    
                    if(!mapControllingValueToDependentValues.containsKey(DeployRecord.NewControllingPicklistValue__c.trim())){
                        mapControllingValueToDependentValues.put(DeployRecord.NewControllingPicklistValue__c.trim(), new Set<String> {DeployRecord.NewDependentPicklistValue__c.trim()});//Stores the Controlling values to Dependent values
                    }
                    else{
                        mapControllingValueToDependentValues.get(DeployRecord.NewControllingPicklistValue__c.trim()).add(DeployRecord.NewDependentPicklistValue__c.trim());
                    }
                    //if(DeployRecord.Operation__c =='Add'){
                        if(!mapDependentValueToControllingValues.containsKey(DeployRecord.NewDependentPicklistValue__c.trim())){
                            mapDependentValueToControllingValues.put(DeployRecord.NewDependentPicklistValue__c.trim(), new Set<String> {DeployRecord.NewControllingPicklistValue__c.trim()});
                        }
                        else{
                            mapDependentValueToControllingValues.get(DeployRecord.NewDependentPicklistValue__c.trim()).add(DeployRecord.NewControllingPicklistValue__c.trim());
                        }
                    //}
                }
                else{
                    
                    if(mapLabelToPicklistApi!=null && !mapLabelToPicklistApi.IsEmpty() && DeployRecord.NewPicklistValue__c!=null && mapLabelToPicklistApi.containsKey(DeployRecord.NewPicklistValue__c)){
                        DeployRecord.NewPicklistValue__c=mapLabelToPicklistApi.get(DeployRecord.NewPicklistValue__c);
                    }
                    setAddPicklistValues.add(DeployRecord.NewPicklistValue__c);
                }
            }
            if(DeployRecord.Operation__c =='Change Dependency'){
                
                if(fieldDependency){
                    
                    if(DeployRecord.NewDependentPicklistValue__c!=null && DeployRecord.ExistingControllingPicklistValue__c!=null){
                        
                        mapChangeControllingValue.put(DeployRecord.NewDependentPicklistValue__c.trim(),DeployRecord.ExistingControllingPicklistValue__c.trim());//Stores the new Dependent picklist to existing controlling picklist
                    }
                    
                }
                
            }
        }
        
        if(mapControllingValueToDependentValues.IsEmpty() && mapDependentValueToControllingValues.IsEmpty() && setDeactivateDependentValues.IsEmpty() && setDeactivatePicklistValues.IsEmpty() && mapExistingPickListToNewValue.IsEmpty() && mapDepExistingPickListToNewValue.IsEmpty() && setAddPicklistValues.IsEmpty()){
            return;
        }
        
        List<MetadataService.CustomField> customfields = new List<MetadataService.CustomField>();

        List<MetadataService.ValueSettings> depValueSettingss = new List<MetadataService.ValueSettings>();
        
        NtnxDynamicPicklistCreation.CustomValueAndStringWrapper customValueWrapper;
        
        Set<String>reActivatePicklistValues = new Set<String>();
        Set<String> depExistingPickListvalues;
        Set<String> custExistingPickListvalues;

        if(depCustomField!=null && depCustomField.valueSet.ValueSettings!=null && !setDeactivatePicklistValues.IsEmpty()){
        for(MetadataService.ValueSettings ValueSettg : depCustomField.valueSet.ValueSettings){

            if(!ValueSettg.controllingFieldValue.IsEmpty() && ValueSettg.controllingFieldValue.size()==1){

                if(!mapChangeControllingValue.containsKey(ValueSettg.valueName) && !setDeactivateDependentValues.contains(ValueSettg.valueName) && setDeactivatePicklistValues.contains(new List<String>(ValueSettg.controllingFieldValue)[0])){
                    system.debug('@@@@@@@@@'+ValueSettg );

                    reActivatePicklistValues.add(ValueSettg.valueName);
                }
            }
            else{
                for(String controllingValue : ValueSettg.controllingFieldValue){
                    if(!mapChangeControllingValue.containsKey(ValueSettg.valueName) && !setDeactivateDependentValues.contains(ValueSettg.valueName) && setDeactivatePicklistValues.contains(controllingValue)){
                       // reActivatePicklistValues.add(ValueSettg.valueName);
                        Set<String> setValues = new Set<String>();
                        setValues.addAll(ValueSettg.controllingFieldValue);
                        setValues.remove(controllingValue);
                        if(!mapChangeControllingValue.containsKey(ValueSettg.valueName)){
                            mapChangeControllingValue.put(ValueSettg.valueName, controllingValue);
                        }
                        else{
                            mapChangeControllingValue.put(ValueSettg.valueName, controllingValue);
                        } 
                        if(!mapDependentValueToControllingValues.containsKey(ValueSettg.valueName)){
                            mapDependentValueToControllingValues.put(ValueSettg.valueName, new Set<String> (setValues));
                        }
                        else{
                            mapDependentValueToControllingValues.get(ValueSettg.valueName).addAll(setValues);
                        } 
                        for(String str : setValues){
                        
                        if(!mapControllingValueToDependentValues.containsKey(str)){
                            mapControllingValueToDependentValues.put(str, new Set<String> {ValueSettg.valueName});//Stores the Controlling values to Dependent values
                        }
                        else{
                            mapControllingValueToDependentValues.get(str).add(ValueSettg.valueName);
                        }
                        
                        }
                        break;
                        }
   
                }
                
                }
            }
          setDeactivateDependentValues.addAll(reActivatePicklistValues);
          depExistingPickListvalues = deactivatePicklist(MetadataService,depCustomField,setDeactivateDependentValues, true, dependentField, objectApiName);
        
        }
        system.debug('@@@@@@@@@reActivatePicklistValues'+reActivatePicklistValues);

         if(customField!=null && !setDeactivatePicklistValues.IsEmpty()){
             custExistingPickListvalues= deactivatePicklist(MetadataService,customField,setDeactivatePicklistValues, false, picklistField, objectApiName);
         }
         
        if(!setDeactivateDependentValues.IsEmpty() || !setDeactivatePicklistValues.IsEmpty()){
        List<MetadataService.CustomField> latestFieldsMetadata = getCustomFieldDetails(MetadataService, listStringCustomFields);//Gets the Custom field details from Metadata service
        
        if(customField!=null)
            customField = latestFieldsMetadata[0];
            
        if(depCustomField!=null)
            depCustomField = latestFieldsMetadata[1];
        
        }
        if(customField!=null)
            customValueWrapper = getExistingPickListValues(customField, mapExistingPickListToNewValue);
        
        //system.debug('@@@@@@@@@dCustomField'+dCustomField.valueSet.ValueSettings.size());
        if(fieldDependency){
            if(depCustomField!=null && depCustomField.valueSet.ValueSettings!=null){
                for(MetadataService.ValueSettings ValueSettg : depCustomField.valueSet.ValueSettings){
                    
                    if(mapDependentValueToControllingValues.containsKey(ValueSettg.valueName)){
                        Set<String> setValues = new Set<String>();
                        setValues.addAll(ValueSettg.controllingFieldValue);
                        if(mapChangeControllingValue.containsKey(ValueSettg.valueName)){
                            setValues.remove(mapChangeControllingValue.get(ValueSettg.valueName));
                            }
                        mapDependentValueToControllingValues.get(ValueSettg.valueName).addAll(setValues);
                    system.debug('@@@@@@@@@mapDependentValueToControllingValues'+mapDependentValueToControllingValues);
                    system.debug('@@@@@@@@@setValues'+setValues);
                    system.debug('@@@@@@@@@setValues'+mapChangeControllingValue);
                        }
                    }
                }
            
            NtnxDynamicPicklistCreation.CustomValueAndStringWrapper depCustomValueWrapper;
            
            if(depCustomField!=null){
                depCustomValueWrapper = getExistingPickListValues(depCustomField, mapDepExistingPickListToNewValue);
                
                for(String reActiveValue : reActivatePicklistValues){
                    MetadataService.CustomValue customValue = createPickListValue(reActiveValue );
                    depCustomValueWrapper.PickListvalues.add(customValue);
                    depCustomValueWrapper.StringPickListvalues.add(reActiveValue);
                }
            }
            
            for(String controllingValue : mapControllingValueToDependentValues.keySet()){
                system.debug('@@@@@@@@@'+controllingValue );
                system.debug('@@@@@@@@@'+mapControllingValueToDependentValues);
                system.debug('@@@@@@@@@'+customValueWrapper.StringPickListvalues);
                                     system.debug('@@@@@@@@@'+mapDependentValueToControllingValues);

                if(customValueWrapper!=null && !customValueWrapper.StringPickListvalues.contains(controllingValue)){
                    system.debug('@@@@@@@@@'+mapControllingValueToDependentValues);
                    MetadataService.CustomValue customValue = createPickListValue(controllingValue);
                    customValueWrapper.PickListvalues.add(customValue); 
                    customValueWrapper.StringPickListvalues.add(controllingValue);
                }
                
                for(String dependentValue : mapControllingValueToDependentValues.get(controllingValue)){
                     system.debug('@@@@@@@@@'+mapDependentValueToControllingValues);
                    if(depCustomValueWrapper!=null && !depCustomValueWrapper.StringPickListvalues.contains(dependentValue)){
                        
                        MetadataService.CustomValue customValue = createPickListValue(dependentValue);
                        depCustomValueWrapper.PickListvalues.add(customValue); 
                        depCustomValueWrapper.StringPickListvalues.add(dependentValue);
                    }
                    
                    MetadataService.ValueSettings ValueSettg = new MetadataService.ValueSettings();
                    
                    if(mapDependentValueToControllingValues.containsKey(dependentValue)){
                        
                        Set<String> listControllingValues = mapDependentValueToControllingValues.get(dependentValue);
                        listControllingValues.add(controllingValue);
                        ValueSettg.controllingFieldValue = new List<String>(listControllingValues);
                    }
                    else{
                        ValueSettg.controllingFieldValue = new List<String>{controllingValue};
                            }
                    ValueSettg.valueName = dependentValue;    
                    depValueSettingss.add(ValueSettg);
                }
            }
            
            MetadataService.ValueSet depPicklistValueSet;
            
            if(depCustomValueWrapper!=null){
                
                depPicklistValueSet = createValueSetAndValueDefinition(depCustomValueWrapper.pickListvalues, dependentField, objectApiName);
                
                if(String.IsNotBlank(picklistField))
                    depPicklistValueSet.controllingField = picklistField.substringAfter('.');
                
                //depValueSettingss.addAll(depCustomField.valueSet.ValueSettings);
                
                 if(depValueSettingss!=null){
                    depPicklistValueSet.valueSettings = depValueSettingss;
                     system.debug('@@@@@@@ValueSettg.depValueSettingss'+depCustomField.valueSet.ValueSettings);
                    }
                
                //Set the valueSet for picklist type
                depCustomField.valueSet = depPicklistValueSet;
                customfields.add(depCustomField);
            }
        }
        
        if(!fieldDependency){
            
            for(String picklistValue : setAddPicklistValues){
                
                if(customValueWrapper!=null && !customValueWrapper.StringPickListvalues.contains(picklistValue)){
                    
                    MetadataService.CustomValue customValue = createPickListValue(picklistValue);
                    customValueWrapper.pickListvalues.add(customValue); 
                    customValueWrapper.StringPickListvalues.add(picklistValue);
                }
            }
        }
        
        MetadataService.ValueSet pickListvalueset;
        
        if(customValueWrapper!=null){
            pickListvalueset = createValueSetAndValueDefinition(customValueWrapper.pickListvalues, picklistField, objectApiName);
            customField.valueSet = pickListvalueset;
            customfields.add(customField);
        }
        
        if(!customfields.IsEmpty()){
            List<Messaging.EmailFileAttachment> listAttachments = createCsvAttachment(MetadataService, listStringCustomFields, picklistField, dependentField, 'Before');
            
            List<MetadataService.SaveResult> lstResults = metadataservice.updateMetadata(customfields);

            String deployStatus = '';
            
            for(MetadataService.SaveResult objResult : lstResults){//check the updated results and copy the status to deployment status
                
                if (objResult.success) {
                    deployStatus = +deployStatus + 'Successfully updated'+'\n';
                    System.debug('Successfully updated');
                }
                else {                       
                    if(objResult.errors.size() > 0){
                        deployStatus = +deployStatus + objResult.errors[0].message;
                        System.debug('eror : ' + objResult.errors[0].message);
                        System.debug('eror : ' + objResult.errors);
                    }
                }
            }
            
            Map<Id,Deployment_Stage__c> mapIdToDeployStatus = new Map<Id,Deployment_Stage__c>();
            
            for(Deployment_Stage__c dStage : listDeploymentStageRecords){
                
                if((dStage.Operation__c=='Deactivate' || dStage.Operation__c=='Relabel')){
                    
                    if(dStage.Type__c=='Field Dependency'){
                        
                        if(String.IsNotBlank(dStage.ExistingControllingPicklistValue__c) && customValueWrapper!=null && !custExistingPickListvalues.contains(dStage.ExistingControllingPicklistValue__c)){
                            
                            deployStatus = 'Controlling Field: '+'"'+dStage.ExistingControllingPicklistValue__c+'"'+' doesn\'t exist please enter correct value';
                        }
                        
                        if(String.IsNotBlank(dStage.ExistingDependentPicklistValue__c) && !depExistingPickListvalues.IsEmpty() && !depExistingPickListvalues.contains(dStage.ExistingDependentPicklistValue__c)){
                            
                            deployStatus = +deployStatus+'\n'+'Dependent Field:' +'"'+dStage.ExistingDependentPicklistValue__c+'"'+' doesn\'t exist please enter correct value';
                        }
                    }
                    else if(dStage.Type__c=='Picklist Only' && String.IsNotBlank(dStage.ExistingPicklistValue__c) && !custExistingPickListvalues.contains(dStage.ExistingPicklistValue__c)){
                        
                        deployStatus = +deployStatus+'\n'+dStage.ExistingPicklistValue__c+' doesn\'t exist please enter correct value';
                        
                    }
                }
                
                Deployment_Stage__c updateDstage = new Deployment_Stage__c(Id=dStage.Id);
                updateDstage.DeploymentStatus__c = deployStatus;
                mapIdToDeployStatus.put(dStage.Id,updateDstage);
            }
            
            if(!mapIdToDeployStatus.IsEmpty()){
                String dStageHeader = 'Id, ObjectApiName__c, ControllingFieldApiName__c,NewControllingPicklistValue__c,ExistingControllingPicklistValue__c,DependentFieldApiName__c,NewDependentPicklistValue__c,ExistingDependentPicklistValue__c,PicklistFieldApiName__c,NewPicklistValue__c,Operation__c,ExistingPicklistValue__c,Type__c,DeploymentStatus__c \n';
                
                for(Deployment_Stage__c dStage : listDeploymentStageRecords){
                    string recordString = '"'+dStage.Id+'","'+dStage.ObjectApiName__c+'","'+dStage.ControllingFieldApiName__c+'","'+dStage.NewControllingPicklistValue__c+'","'+dStage.ExistingControllingPicklistValue__c+'","'+dStage.DependentFieldApiName__c+'","'+dStage.NewDependentPicklistValue__c+'","'+dStage.ExistingDependentPicklistValue__c+'","'+dStage.PicklistFieldApiName__c+'","'+dStage.NewPicklistValue__c+'","'+dStage.ExistingPicklistValue__c+'","'+dStage.Operation__c+'","'+dStage.Type__c+'","'+mapIdToDeployStatus.get(dStage.Id).DeploymentStatus__c+'"\n';
                    dStageHeader = dStageHeader+recordString.replace('null','');
                }
                
                listAttachments.addAll(createCsvAttachment(MetadataService, listStringCustomFields, picklistField, dependentField, 'After'));
                
                Messaging.EmailFileAttachment statusAttachment = createEmailAttachment('DeploymentStatus', dStageHeader);
                
                listAttachments.add(statusAttachment);
                
                List<NtnxEmailMessage> listEmailMessage = new List<NtnxEmailMessage>();
                NtnxEmailMessage emMessage = New NtnxEmailMessage();
                emMessage.setTargetObjectId(userInfo.getUserId());
                emMessage.setSubject('Picklist Deployment Status');
                emMessage.setPlainTextBody('Hi, Please find the attached Deployment status, Controlling field Picklist values/Dependent field picklist values');
                emMessage.setSaveAsActivity(false);
                emMessage.setFileAttachments(new Messaging.EmailFileAttachment[listAttachments]);
                listEmailMessage.add(emMessage);
                //NtnxEmailMessage.sendEmail(listEmailMessage);
                
                List<database.SaveResult> lstDeployResults = database.update(mapIdToDeployStatus.values());
                
            }
        }
    }
    
   /*Method: getExistingPickListValues
    * Author: Vulsala Srinivasulu
    * Description: Creates the Custom values and Picklist as wrapper class
    * Jira Ticket: BA-79992
    */
    
    public static NtnxDynamicPicklistCreation.customValueAndStringWrapper getExistingPickListValues(MetadataService.CustomField customField, Map<String, String> mapExistingPickListToNewValue){
        
        List<MetadataService.CustomValue> pickListvalues = new List<MetadataService.CustomValue>();
        Set<String> StringPickListvalues = new Set<String>();//Stores all picklist as strings.
        
        for(MetadataService.CustomValue objCustomValue : customField.valueSet.valueSetDefinition.value){
                       
           if(!mapExistingPickListToNewValue.IsEmpty() && mapExistingPickListToNewValue.containsKey(objCustomValue.fullName)){
               objCustomValue.label = mapExistingPickListToNewValue.get(objCustomValue.fullName);  
                    
           }                                 
                pickListvalues.add(objCustomValue); 
                StringPickListvalues.add(objCustomValue.fullName);
            }
        NtnxDynamicPicklistCreation.CustomValueAndStringWrapper customValue = new NtnxDynamicPicklistCreation.CustomValueAndStringWrapper(PickListvalues, StringPickListvalues);
        
        return customValue;
    }
    
     /*Method: createPickListValue
    * Author: Vulsala Srinivasulu
    * Description: Creates the Custom value from string Picklist
    * Jira Ticket: BA-79992
    */
    
    public static MetadataService.CustomValue createPickListValue(String pickListValue){
        
        MetadataService.CustomValue customValue = new MetadataService.CustomValue();
        customValue.fullName = pickListValue; //API name of picklist value
        customValue.default_x = False;
        customValue.description = '';
        customValue.isActive = true;
        customValue.label = pickListValue;                
        
        return customValue;
    }
    
   /*Method: getLabelToPicklistApi
    * Author: Vulsala Srinivasulu
    * Description: Get the Picklist label to Api values.
    * Jira Ticket: BA-79992
    */
    
    public static Map<String,String> getLabelToPicklistApi(MetadataService.CustomField customField){
        
        Map<String,String> mapLabelToPicklistApi = new Map<String,String>();
        
        for(MetadataService.CustomValue objCustomValue : customField.valueSet.valueSetDefinition.value){
            
            if(objCustomValue.label != objCustomValue.fullName){
                mapLabelToPicklistApi.put(objCustomValue.label, objCustomValue.fullName);
            }  
        }
        return mapLabelToPicklistApi;
    }
    
     /*Method: customValueAndStringWrapper
    * Author: Vulsala Srinivasulu
    * Description: Create wrapper class with Custom values and Picklists as Strings.
    * Jira Ticket: BA-79992
    */
    public class customValueAndStringWrapper{
        
        List<MetadataService.CustomValue> pickListvalues; 
        Set<String> stringPickListvalues;
        
        public customValueAndStringWrapper(List<MetadataService.CustomValue> pickListvalues, Set<String> stringPickListvalues){
            
            this.pickListvalues = pickListvalues;
            this.stringPickListvalues = stringPickListvalues;
        }
    }
    
     /*Method: customValueAndStringWrapper
    * Author: Vulsala Srinivasulu
    * Description: Create wrapper class with Custom values and Picklists as Strings.
    * Jira Ticket: BA-79992
    */
    public class controllingAndDependentWrapper{
        
        Map<String, Set<String>> mapControllingValueToDependentValues;//Stores controlling values to dependent values
        Map<String, Set<String>> mapDependentValueToControllingValues;
        Set<String>reActivatePicklistValues;
        Set<String> allExistingPicklists;  
              
        public controllingAndDependentWrapper(Map<String, Set<String>> mapControllingValueToDependentValues, Map<String, Set<String>> mapDependentValueToControllingValues,  Set<String>reActivatePicklistValues, Set<String> allExistingPicklists){
            
            this.mapControllingValueToDependentValues = mapControllingValueToDependentValues;
            this.mapDependentValueToControllingValues = mapDependentValueToControllingValues;
            this.reActivatePicklistValues = reActivatePicklistValues;
            this.allExistingPicklists = allExistingPicklists;
        }
    }
    
    /*Method: getCustomFieldDetails
    * Author: Vulsala Srinivasulu
    * Description: Get the full metadata of custom fields using Metadata Service 
    * Jira Ticket: BA-79992
    */
    public static List<MetadataService.CustomField> getCustomFieldDetails(MetadataService.MetadataPort MetadataService, List<String> listStringCustomFields){
        
        List<MetadataService.CustomField> customFieldsMetadata = (List<MetadataService.CustomField>) metadataservice.readMetadata('CustomField', new String[listStringCustomFields]).getRecords();
        
        return customFieldsMetadata ;
    }
    
    /*Method: createValueSetAndValueDefinition
    * Author: Vulsala Srinivasulu
    * Description: Create ValueSet,ValueSetValuesDefinition and check the field has Controlling field or not 
    * Jira Ticket: BA-79992
    */
   
    public static MetadataService.ValueSet createValueSetAndValueDefinition(List<MetadataService.CustomValue> pickListvalues, String fieldApiName, String objectApi){
        
        List<FieldDefinition> depFieldD = [SELECT ControllingFieldDefinitionId FROM FieldDefinition WHERE EntityDefinition.QualifiedApiName =:objectApi AND QualifiedApiName =:fieldApiName.substringAfter('.') AND ControllingFieldDefinitionId!=null];
        
        //For each ValueSet, we have either ValueSetValuesDefinition or ValueSettings and some other attributes
        MetadataService.ValueSetValuesDefinition valueDefinition = new MetadataService.ValueSetValuesDefinition();
        //It will be list of CustomValue
        valueDefinition.value = pickListvalues;
        valueDefinition.sorted = false;
        
        //Create the valueSet for picklist type
        MetadataService.ValueSet pickListvalueset = new MetadataService.ValueSet();
        //set the valueSetDefinition
        pickListvalueset.valueSetDefinition = ValueDefinition;
        
        if(!depFieldD.IsEmpty()){
            
            //check the field has Controlling field or not.if there then it adds to valueset
            List<FieldDefinition> contFieldD = [SELECT QualifiedApiName,DurableId,ControllingFieldDefinitionId FROM FieldDefinition WHERE EntityDefinition.QualifiedApiName =:objectApi AND DurableId=:depFieldD[0].ControllingFieldDefinitionId];
            
            if(!contFieldD.IsEmpty())
                pickListvalueset.controllingField = contFieldD[0].QualifiedApiName;
        }
        return pickListvalueset;
    }
    
    /*Method: createEmailAttachment
    * Author: Vulsala Srinivasulu
    * Description: Create email attachment from csv file
    * Jira Ticket: BA-79992
    */
    
    public static Messaging.EmailFileAttachment createEmailAttachment(String fileName, String setBody){
        
        Messaging.EmailFileAttachment attachment = new Messaging.EmailFileAttachment();
        attachment.setFileName(fileName+'.csv');
        attachment.setBody(Blob.valueOf(setBody));
        return attachment;
    }
    
    /*Method: createCsvAttachment
    * Author: Vulsala Srinivasulu
    * Description: Create Csv attachment from custom field details 
    * Jira Ticket: BA-79992
    */
    public static List<Messaging.EmailFileAttachment> createCsvAttachment(MetadataService.MetadataPort MetadataService, List<String> listStringCustomFields, String picklistField, String dependentField, String beforeAfter){
        
        List<MetadataService.CustomField> fieldsMetadataStatus = getCustomFieldDetails(MetadataService, listStringCustomFields);
        
        Boolean contPlusDep = false;
        String dependentHeader ='';
        
        List<Messaging.EmailFileAttachment> listAttachments = new List<Messaging.EmailFileAttachment>();
        
        if(String.IsNotBlank(picklistField) && String.IsNotBlank(dependentField)) contPlusDep = true;
        
        if(contPlusDep)dependentHeader = picklistField+','+dependentField+'\n';
        
        String picklistsHeader = picklistField+'\n';
        
        for(MetadataService.CustomField custField : fieldsMetadataStatus){ 
            
            if(custField.valueSet.ValueSettings!=null && contPlusDep){
                
                for(MetadataService.ValueSettings ValueSettg : custField.valueSet.ValueSettings){
                    
                    for(String controllingValue : ValueSettg.controllingFieldValue){
                        string picklistString = '"'+controllingValue+'","'+ValueSettg.valueName+'"\n';
                        dependentHeader = dependentHeader+picklistString;
                    }
                }
            }
            else {
                for(MetadataService.CustomValue objCustomValue : custField.valueSet.valueSetDefinition.value){
                    string picklistString = '"'+objCustomValue.label+'"\n';
                    picklistsHeader = picklistsHeader+picklistString;
                }
            }
        }
        
        if(contPlusDep){
            Messaging.EmailFileAttachment dependentAttachment = createEmailAttachment(beforeAfter+'_'+dependentField, dependentHeader);
            listAttachments.add(dependentAttachment);
        }
        
        Messaging.EmailFileAttachment picklistattachment = createEmailAttachment(beforeAfter+'_'+picklistField, picklistsHeader);
        listAttachments.add(picklistattachment);
        
        return listAttachments;
    }
    
    
    public static Set<String> deactivatePicklist(MetadataService.MetadataPort MetadataService, MetadataService.CustomField customField,Set<String>setDeactivatePicklistValues,Boolean fieldDependency, String fieldApiName, String objectApi){
    
        List<MetadataService.CustomValue> pickListvalues = new List<MetadataService.CustomValue>();
        Set<String> allExistingPicklists = new Set<String>();//Stores all existing picklist as strings.
        
        for(MetadataService.CustomValue objCustomValue : customField.valueSet.valueSetDefinition.value){
            allExistingPicklists.add(objCustomValue.fullName);
            if(setDeactivatePicklistValues.contains(objCustomValue.fullName)){  
                objCustomValue.isActive = false;
            }
             pickListvalues.add(objCustomValue); 
        }
        
        MetadataService.ValueSet pickListvalueset = createValueSetAndValueDefinition(pickListvalues, fieldApiName, objectApi);
        if(fieldDependency)
        pickListvalueset.valueSettings = customField.valueSet.ValueSettings;
        
        customField.valueSet = pickListvalueset;
        
        if(pickListvalueset!=null)
        List<MetadataService.SaveResult> lstResults = metadataservice.updateMetadata(new List<MetadataService.CustomField>{customField});    
    
        return allExistingPicklists;
    }
}
