
//  FilesDownManage.m
//  Created by yu on 13-1-21.
//

#import "FilesDownManage.h"
#import "Reachability.h"



#define TEMPPATH [CommonHelper getTempFolderPathWithBasepath:_basepath]

@implementation FilesDownManage
@synthesize downinglist=_downinglist;
@synthesize fileInfo = _fileInfo;
@synthesize downloadDelegate=_downloadDelegate;
@synthesize finishedlist=_finishedList;
@synthesize buttonSound=_buttonSound;
@synthesize downloadCompleteSound=_downloadCompleteSound;
@synthesize isFistLoadSound=_isFirstLoadSound;
@synthesize basepath = _basepath;
@synthesize filelist = _filelist;
@synthesize targetPathArray = _targetPathArray;
@synthesize VCdelegate = _VCdelegate;
@synthesize count;
static   FilesDownManage *sharedFilesDownManage = nil;
NSInteger  maxcount;



-(void)playButtonSound
{
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
	NSString *audioAlert = [userDefaults valueForKey:@"kAudioAlertSetting"];

	if( NO == [audioAlert boolValue] )
    {
        return;
    }
    NSURL *url=[[[NSBundle mainBundle]resourceURL] URLByAppendingPathComponent:@"btnEffect.wav"];
    NSError *error;
    if(self.buttonSound==nil)
    {
        self.buttonSound=[[[AVAudioPlayer alloc] initWithContentsOfURL:url error:&error] autorelease];
        if(!error)
        {
            NSLog(@"%@",[error description]);
        }
    }
    if([audioAlert isEqualToString:@"YES"]||audioAlert==nil)//播放声音
    {
        if(!self.isFistLoadSound)
        {
            self.buttonSound.volume=1.0f;
        }
    }
    else
    {
        self.buttonSound.volume=0.0f;
    }
    [self.buttonSound play];
}

-(void)playDownloadSound
{
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
	NSString *result = [userDefaults valueForKey:@"kAudioAlertSetting"];
    
	if( NO == [result boolValue] )
    {
        return;
    }

    NSURL *url=[[[NSBundle mainBundle]resourceURL] URLByAppendingPathComponent:@"download-complete.wav"];
    NSError *error;
    if(self.downloadCompleteSound==nil)
    {
        self.downloadCompleteSound=[[[AVAudioPlayer alloc] initWithContentsOfURL:url error:&error] autorelease];
        if(!error)
        {
            NSLog(@"%@",[error description]);
        }
    }
    if([result isEqualToString:@"YES"]||result==nil)//播放声音
    {
        if(!self.isFistLoadSound)
        {
            self.downloadCompleteSound.volume=1.0f;
        }
    }
    else
    {
        self.downloadCompleteSound.volume=0.0f;
    }
    [self.downloadCompleteSound play];
}
-(NSArray *)sortbyTime:(NSArray *)array{
    NSArray *sorteArray1 = [array sortedArrayUsingComparator:^(id obj1, id obj2){
        FileModel *file1 = (FileModel *)obj1;
        FileModel *file2 = (FileModel *)obj2;
        MyLog(@"%@",file1);
        NSDate *date1 = [CommonHelper makeDate:file1.time];
        NSDate *date2 = [CommonHelper makeDate:file2.time];
        if ([[date1 earlierDate:date2]isEqualToDate:date2]) {
            return (NSComparisonResult)NSOrderedDescending;
        }
        
        if ([[date1 earlierDate:date2]isEqualToDate:date1]) {
            return (NSComparisonResult)NSOrderedAscending;
        }
        
        return (NSComparisonResult)NSOrderedSame;
    }];
    return sorteArray1;
}
-(NSArray *)sortRequestArrbyTime:(NSArray *)array{
    NSArray *sorteArray1 = [array sortedArrayUsingComparator:^(id obj1, id obj2){
        //
        FileModel* file1 =   [((ASIHTTPRequest *)obj1).userInfo objectForKey:@"File"];
        FileModel *file2 =   [((ASIHTTPRequest *)obj2).userInfo objectForKey:@"File"];
        
        NSDate *date1 = [CommonHelper makeDate:file1.time];
        NSDate *date2 = [CommonHelper makeDate:file2.time];
        if ([[date1 earlierDate:date2]isEqualToDate:date2]) {
            return (NSComparisonResult)NSOrderedDescending;
        }
        
        if ([[date1 earlierDate:date2]isEqualToDate:date1]) {
            return (NSComparisonResult)NSOrderedAscending;
        }
        
        return (NSComparisonResult)NSOrderedSame;
    }];
    return sorteArray1;
}

/**
 *   videoTime:(NSString *)vedioTime
 creatTime:(NSString *)creatTime
 bgImageString:(NSString *)bgImageString
 */
-(void)saveDownloadFile:(FileModel*)fileinfo{
    NSData *imagedata =UIImagePNGRepresentation(fileinfo.fileimage);

   NSDictionary *filedic = [NSDictionary dictionaryWithObjectsAndKeys:fileinfo.fileName,@"filename",fileinfo.teacherName,@"teacherName",fileinfo.videoID,@"videoID",fileinfo.vedioTime,@"vedioTime",fileinfo.creatTime,@"creatTime",fileinfo.bgImageString,@"bgImageString",fileinfo.teacherJS,@"teacherJS",fileinfo.imageUrl,@"imageUrl",fileinfo.time,@"time",fileinfo.fileSize,@"filesize",fileinfo.targetPath,@"filepath",imagedata,@"fileimage", nil];
    
    NSString *plistPath = [fileinfo.tempPath stringByAppendingPathExtension:@"plist"];
    if (![filedic writeToFile:plistPath atomically:YES]) {
        NSLog(@"write plist fail");
    }
}
-(void)beginRequest:(FileModel *)fileInfo isBeginDown:(BOOL)isBeginDown
{
    for(ASIHTTPRequest *tempRequest in self.downinglist)
    {
        
        /**
        注意这里判读是否是同一下载的方法，asihttprequest 有三种url：
        url，originalurl，redirectURL
        经过实践，应该使用originalurl,就是最先获得到的原下载地址
        **/
        
        NSLog(@"%@",[tempRequest.url absoluteString]);
        if([[[tempRequest.originalURL absoluteString]lastPathComponent] isEqualToString:[fileInfo.fileURL lastPathComponent]])
        {
            if ([tempRequest isExecuting]&&isBeginDown) {
                return;
            }else if ([tempRequest isExecuting]&&!isBeginDown)
            {
              [tempRequest setUserInfo:[NSDictionary dictionaryWithObject:fileInfo forKey:@"File"]];
              [tempRequest cancel];
                [self.downloadDelegate updateCellProgress:tempRequest];
                return;
            }
        }
    }

    [self saveDownloadFile:fileInfo];
    
    //NSLog(@"targetPath %@",fileInfo.targetPath);
    //按照获取的文件名获取临时文件的大小，即已下载的大小

    fileInfo.isFirstReceived=YES;
    NSFileManager *fileManager=[NSFileManager defaultManager];
    NSData *fileData=[fileManager contentsAtPath:fileInfo.tempPath];
    NSInteger receivedDataLength=[fileData length];
    fileInfo.fileReceivedSize=[NSString stringWithFormat:@"%d",receivedDataLength];
    
    NSLog(@"start down::已经下载：%@",fileInfo.fileReceivedSize);
   // [self limitMaxLines];
    ASIHTTPRequest *request=[[ASIHTTPRequest alloc] initWithURL:[NSURL URLWithString:fileInfo.fileURL]];
    request.delegate=self;
    [request setDownloadDestinationPath:[NSString stringWithFormat:@"%@",fileInfo.targetPath]];
    [request setTemporaryFileDownloadPath:[NSString stringWithFormat:@"%@",fileInfo.tempPath]];
    [request setDownloadProgressDelegate:self];
    [request setNumberOfTimesToRetryOnTimeout:2];
    // [request setShouldContinueWhenAppEntersBackground:YES];

    [request setAllowResumeForFileDownloads:YES];//支持断点续传

    
    [request setUserInfo:[NSDictionary dictionaryWithObject:fileInfo forKey:@"File"]];//设置上下文的文件基本信息
    [request setTimeOutSeconds:30.0f];
    if (isBeginDown) {
        [request startAsynchronous];
    }
    
    //如果文件重复下载或暂停、继续，则把队列中的请求删除，重新添加
    BOOL exit = NO;
    for(ASIHTTPRequest *tempRequest in self.downinglist)
    {
        MyLog(@"!!!!---::%@",[[tempRequest.url absoluteString]lastPathComponent]);
        MyLog(@"%@",[[tempRequest.originalURL absoluteString]lastPathComponent]);
        MyLog(@"%@",[fileInfo.fileURL lastPathComponent]);
        if([[[tempRequest.originalURL absoluteString]lastPathComponent] isEqualToString:[fileInfo.fileURL lastPathComponent]]|| [[[tempRequest.url absoluteString]lastPathComponent] isEqualToString:[fileInfo.fileURL lastPathComponent]])
        {
            [self.downinglist replaceObjectAtIndex:[_downinglist indexOfObject:tempRequest] withObject:request ];
            
            exit = YES;
            break;
        }
    }
    
    if (!exit) {
       
        [self.downinglist addObject:request];
         NSLog(@"EXIT!!!!---::%@",[request.url absoluteString]);
    }
    [self.downloadDelegate updateCellProgress:request];
    [request release];
    
}

-(void)resumeRequest:(ASIHTTPRequest *)request{
    NSInteger max = maxcount;
    FileModel *fileInfo =  [request.userInfo objectForKey:@"File"];
    NSInteger downingcount =0;
    NSInteger indexmax =-1;
    for (FileModel *file in _filelist) {
        if (file.downloadState==Downloading) {
            downingcount++;
            if (downingcount==max) {
                indexmax = [_filelist indexOfObject:file];
            }
        }
    }//此时下载中数目是否是最大，并获得最大时的位置Index
    if (downingcount==max) {
        FileModel *file  = [_filelist objectAtIndex:indexmax];
            if (file.downloadState==Downloading) {
                file.downloadState=WillDownload;
            }
    }//中止一个进程使其进入等待

    for (FileModel *file in _filelist) {
        if ([file.fileName isEqualToString:fileInfo.fileName]) {
			file.downloadState = Downloading;
            file.error = NO;
        }
    }//重新开始此下载
    [self startLoad];
}
-(void)stopRequest:(ASIHTTPRequest *)request{
    NSInteger max = maxcount;
    if([request isExecuting])
    {
        [request cancel];
    }
    FileModel *fileInfo =  [request.userInfo objectForKey:@"File"];
    for (FileModel *file in _filelist) {
        if ([file.fileName isEqualToString:fileInfo.fileName]) {

			file.downloadState = StopDownload;
            break;
        }
    }
    NSInteger downingcount =0;

    for (FileModel *file in _filelist) {
        if (file.downloadState==Downloading) {
            downingcount++;
        }
    }
    if (downingcount<max) {
        for (FileModel *file in _filelist) {
            if (file.downloadState==WillDownload){
				file.downloadState=Downloading;
                break;
            }
        }
    }
    [self startLoad];
//    fileInfo.isDownloading = NO;
//    fileInfo.willDownloading = NO;
//    [request cancel];

   
//    [self startWaitingRequest];


    
}
-(void)deleteRequest:(ASIHTTPRequest *)request{
    bool isexecuting = NO;
    if([request isExecuting])
    {
        [request cancel];
        isexecuting = YES;
    }
    NSFileManager *fileManager=[NSFileManager defaultManager];
    NSError *error;
    FileModel *fileInfo=(FileModel*)[request.userInfo objectForKey:@"File"];
    NSString *path=fileInfo.tempPath;

    NSString *configPath=[NSString stringWithFormat:@"%@.plist",path];
    [fileManager removeItemAtPath:path error:&error];
    [fileManager removeItemAtPath:configPath error:&error];
   // [self deleteImage:fileInfo];
    
    if(!error)
    {
        NSLog(@"%@",[error description]);
    }

    NSInteger delindex =-1;
    for (FileModel *file in _filelist) {
        if ([file.fileName isEqualToString:fileInfo.fileName]) {
            delindex = [_filelist indexOfObject:file];
            break;
        }
    }
    if (delindex!=NSNotFound) 
    [_filelist removeObjectAtIndex:delindex];
  
    [_downinglist removeObject:request];
    
    if (isexecuting) {
       // [self startWaitingRequest];
        [self startLoad];
    }
     self.count = [_filelist count];
}
-(void)clearAllFinished{
    [_finishedList removeAllObjects];
}
-(void)clearAllRquests{
    NSFileManager *fileManager=[NSFileManager defaultManager];
    NSError *error;
    for (ASIHTTPRequest *request in _downinglist) {
        if([request isExecuting])
            [request cancel];
        FileModel *fileInfo=(FileModel*)[request.userInfo objectForKey:@"File"];
        NSString *path=fileInfo.tempPath;;
        NSString *configPath=[NSString stringWithFormat:@"%@.plist",path];
        [fileManager removeItemAtPath:path error:&error];
        [fileManager removeItemAtPath:configPath error:&error];
      //  [self deleteImage:fileInfo];
        if(!error)
        {
            NSLog(@"%@",[error description]);
        }

    }
    [_downinglist removeAllObjects];
    [_filelist removeAllObjects];
}

-(FileModel *)getTempfile:(NSString *)path{
    NSDictionary *dic = [NSDictionary dictionaryWithContentsOfFile:path];
    FileModel *file = [[[FileModel alloc]init]autorelease];
    file.fileName = [dic objectForKey:@"filename"];
    file.fileType = [file.fileName pathExtension ];
    file.fileURL = [dic objectForKey:@"fileurl"];
    file.teacherName = dic[@"teacherName"];
    file.teacherJS = dic[@"teacherJS"];
    file.imageUrl = dic[@"imageUrl"];
    file.videoID = dic[@"videoID"];
    file.vedioTime = dic[@"vedioTime"];
    file.creatTime = dic[@"creatTime"];
    file.bgImageString = dic[@"bgImageString"];
    file.fileSize = [dic objectForKey:@"filesize"];
    file.fileReceivedSize= [dic objectForKey:@"filerecievesize"];
    self.basepath = [dic objectForKey:@"basepath"];
    self.TargetSubPath = [dic objectForKey:@"tarpath"];
    NSString*  path1= [CommonHelper getTargetPathWithBasepath:_basepath subpath:_TargetSubPath];
    path1 = [path1 stringByAppendingPathComponent:file.fileName];
    file.targetPath = path1;
    NSString *tempfilePath= [TEMPPATH stringByAppendingPathComponent: file.fileName];
    file.tempPath = tempfilePath;
    file.time = [dic objectForKey:@"time"];
    file.fileimage = [UIImage imageWithData:[dic objectForKey:@"fileimage"]];
	file.downloadState =StopDownload;
   // file.isFirstReceived = YES;
    file.error = NO;
    
    NSData *fileData=[[NSFileManager defaultManager ] contentsAtPath:file.tempPath];
    NSInteger receivedDataLength=[fileData length];
    file.fileReceivedSize=[NSString stringWithFormat:@"%d",receivedDataLength];
    return file;

    
}
/*
 将本地的未下载完成的临时文件加载到正在下载列表里,但是不接着开始下载

 */
-(void)loadTempfiles
{
    
    NSFileManager *fileManager=[NSFileManager defaultManager];
    NSError *error;
    NSArray *filelist=[fileManager contentsOfDirectoryAtPath:TEMPPATH error:&error];
    if(!error)
    {
        NSLog(@"%@",[error description]);
    }
    NSMutableArray *filearr = [[NSMutableArray alloc]init];
    for(NSString *file in filelist)
    {
        NSString *filetype = [file  pathExtension];
        if([filetype isEqualToString:@"plist"])
           [filearr addObject:[self getTempfile:[TEMPPATH stringByAppendingPathComponent:file]]];
    }
   
    NSArray* arr =  [self sortbyTime:(NSArray *)filearr];
    [_filelist addObjectsFromArray:arr];
    
    [self startLoad];
    [filearr release];
}
/*
	将本地已经下载完成的文件加载到已下载列表里
 */
-(void)loadFinishedfiles
{
    NSString *document = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents"];
    NSString *plistPath = [[document stringByAppendingPathComponent:self.basepath]stringByAppendingPathComponent:@"finishPlist.plist"];
    if ([[NSFileManager defaultManager]fileExistsAtPath:plistPath]) {
        NSMutableArray *finishArr = [[NSMutableArray alloc]initWithContentsOfFile:plistPath];
        for (NSDictionary *dic in finishArr) {
            FileModel *file = [[FileModel alloc]init];
            file.fileName = [dic objectForKey:@"filename"];
            file.fileType = [file.fileName pathExtension ];
            file.fileSize = [dic objectForKey:@"filesize"];
            file.teacherName = dic[@"teacherName"];
            file.videoID = dic[@"videoID"];
            file.vedioTime = dic[@"vedioTime"];
            file.creatTime = dic[@"creatTime"];
            file.bgImageString = dic[@"bgImageString"];
            file.teacherJS = dic[@"teacherJS"];
            file.imageUrl = dic[@"imageUrl"];
            file.targetPath = [dic objectForKey:@"filepath"];
            file.time = [dic objectForKey:@"time"];
            file.fileimage = [UIImage imageWithData:[dic objectForKey:@"fileimage"]];
            [_finishedList addObject:file];
            [file release];
        }
        //self.finishedlist = finishArr;
        [finishArr release];
    }
//    else
//        [[NSFileManager defaultManager]createFileAtPath:plistPath contents:nil attributes:nil];

}

-(void)saveFinishedFile{
     //[_finishedList addObject:file];
    if (_finishedList==nil) {
        return;
    }
    NSMutableArray *finishedinfo = [[NSMutableArray alloc]init];
    for (FileModel *fileinfo in _finishedList) {
        NSData *imagedata =UIImagePNGRepresentation(fileinfo.fileimage);
        NSDictionary *filedic = [NSDictionary dictionaryWithObjectsAndKeys:fileinfo.fileName,@"filename",fileinfo.teacherName,@"teacherName",fileinfo.videoID,@"videoID",fileinfo.vedioTime,@"vedioTime",fileinfo.creatTime,@"creatTime",fileinfo.bgImageString,@"bgImageString",fileinfo.teacherJS,@"teacherJS",fileinfo.imageUrl,@"imageUrl",fileinfo.time,@"time",fileinfo.fileSize,@"filesize",fileinfo.targetPath,@"filepath",imagedata,@"fileimage", nil];
        [finishedinfo addObject:filedic];
    }
    NSString *document = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents"];
    NSString *plistPath = [[document stringByAppendingPathComponent:self.basepath]stringByAppendingPathComponent:@"finishPlist.plist"];
    if (![finishedinfo writeToFile:plistPath atomically:YES]) {
        NSLog(@"write plist fail");
    }
    [finishedinfo release];
}
-(void)deleteFinishFile:(FileModel *)selectFile{
    [_finishedList removeObject:selectFile];
	NSFileManager* fm = [NSFileManager defaultManager];
	if ([fm fileExistsAtPath:selectFile.targetPath]) {
		[fm removeItemAtPath:selectFile.targetPath error:nil];
	}
    [self saveFinishedFile];
}
#pragma mark -- 入口 --
-(void)downFileUrl:(NSString*)url
          filename:(NSString*)name
      teahcherName:(NSString *)teaherName
         teacherJS:(NSString *)teacherJS
           imagURL:(NSString *)imageUrl
        filetarget:(NSString *)path
         fileimage:(UIImage *)image
           videoID:(NSString *)videoID
         videoTime:(NSString *)vedioTime
         creatTime:(NSString *)creatTime
     bgImageString:(NSString *)bgImageString

{
    
    //因为是重新下载，则说明肯定该文件已经被下载完，或者有临时文件正在留着，所以检查一下这两个地方，存在则删除掉
    self.TargetSubPath = path;
    if (_fileInfo!=nil) {
        [_fileInfo release];
        
        _fileInfo = nil;
    }
    _fileInfo = [[FileModel alloc]init];
	if (!name) {
		name = [url lastPathComponent];
	}
    _fileInfo.fileName = name;
    _fileInfo.teacherName = teaherName;
    _fileInfo.teacherJS = teacherJS;
    _fileInfo.fileURL = url;
    _fileInfo.imageUrl = imageUrl;
    _fileInfo.videoID = videoID;
    _fileInfo.vedioTime = vedioTime;
    _fileInfo.creatTime = creatTime;
    _fileInfo.bgImageString = bgImageString;
    
  
      NSDate *myDate = [NSDate date];
   
    _fileInfo.time = [CommonHelper dateToString:myDate];
     MyLog(@"%@",_fileInfo.time);
   // NSInteger index=[name rangeOfString:@"."].location;
    _fileInfo.fileType=[name pathExtension];
    path= [CommonHelper getTargetPathWithBasepath:_basepath subpath:path];
    path = [path stringByAppendingPathComponent:name];
      _fileInfo.targetPath = path ;
    _fileInfo.fileimage = image;
	_fileInfo.downloadState = Downloading;
    _fileInfo.error = NO;
    _fileInfo.isFirstReceived = YES;
    NSString *tempfilePath= [TEMPPATH stringByAppendingPathComponent: _fileInfo.fileName]  ;
    _fileInfo.tempPath = tempfilePath;
    if([CommonHelper isExistFile: _fileInfo.targetPath])//已经下载过一次
    {
        UIAlertView *alert=[[UIAlertView alloc] initWithTitle:@"温馨提示" message:@"该文件已下载，是否重新下载？" delegate:self cancelButtonTitle:@"取消" otherButtonTitles:@"确定", nil];
        [alert show];
        [alert release];
        return;
    }
//    //存在于临时文件夹里
    tempfilePath =[tempfilePath stringByAppendingString:@".plist"];
    if([CommonHelper isExistFile:tempfilePath])
    {
        UIAlertView *alert=[[UIAlertView alloc] initWithTitle:@"温馨提示" message:@"该文件已经在下载列表中了，是否重新下载？" delegate:self cancelButtonTitle:@"取消" otherButtonTitles:@"确定", nil];
        [alert show];
        [alert release];
        return;
    }
    
    //若不存在文件和临时文件，则是新的下载
    [self.filelist addObject:_fileInfo];
    
    [self startLoad];
    if(self.VCdelegate!=nil && [self.VCdelegate respondsToSelector:@selector(allowNextRequest)])
    {
        [self.VCdelegate allowNextRequest];
    }else{
           UIAlertView *alert=[[UIAlertView alloc] initWithTitle:@"温馨提示" message:@"该文件成功添加到下载队列" delegate:self cancelButtonTitle:@"确定" otherButtonTitles:nil, nil];
           [alert show];
           [alert release];
    }
    return;

}

-(void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if(buttonIndex==1)//确定按钮
    {

        NSFileManager *fileManager=[NSFileManager defaultManager];
        NSError *error;
        NSInteger delindex =-1;
        if([CommonHelper isExistFile:_fileInfo.targetPath])//已经下载过一次该音乐
        {
            if ([fileManager removeItemAtPath:_fileInfo.targetPath error:&error]!=YES) {
   
                    NSLog(@"删除文件出错:%@",[error localizedDescription]);
            }

 
        }else{
            for(ASIHTTPRequest *request in self.downinglist)
            {
                FileModel *fileModel=[request.userInfo objectForKey:@"File"];
                if([fileModel.fileName isEqualToString:_fileInfo.fileName])
                {
                    //[self.downinglist removeObject:request];
                    if ([request isExecuting]) {
                        [request cancel];
                    }
                    delindex = [_downinglist indexOfObject:request];
                  //  [self deleteImage:fileModel];
                    break;
                }
            }
            [_downinglist removeObjectAtIndex:delindex];
            
            for (FileModel *file in _filelist) {
                if ([file.fileName isEqualToString:_fileInfo.fileName]) {
                    delindex = [_filelist indexOfObject:file];
                    break;
                }
            }
            [_filelist removeObjectAtIndex:delindex];
        //存在于临时文件夹里
       NSString * tempfilePath =[_fileInfo.tempPath stringByAppendingString:@".plist"];
        if([CommonHelper isExistFile:tempfilePath])
        {   
            if ([fileManager removeItemAtPath:tempfilePath error:&error]!=YES) {
                 NSLog(@"删除临时文件出错:%@",[error localizedDescription]);
            }

        }
        if([CommonHelper isExistFile:_fileInfo.tempPath])
        {
            if ([fileManager removeItemAtPath:_fileInfo.tempPath error:&error]!=YES) {
                 NSLog(@"删除临时文件出错:%@",[error localizedDescription]);
            }
        }

        }
        
        self.fileInfo.fileReceivedSize=[CommonHelper getFileSizeString:@"0"];
        [_filelist addObject:_fileInfo];
        [self startLoad];
//        UIAlertView *alert=[[UIAlertView alloc] initWithTitle:@"温馨提示" message:@"该文件已经添加到您的下载列表中了！" delegate:self cancelButtonTitle:@"确定" otherButtonTitles:nil, nil];
//        [alert show];
//        [alert release];

    }
    if(self.VCdelegate!=nil && [self.VCdelegate respondsToSelector:@selector(allowNextRequest)])
    {
        [self.VCdelegate allowNextRequest];
    }
}
-(void)startLoad{
    /*下载的三种状态，下载中，等待下载，停止下载
     所有任务以添加时间排序。
     */

    NSInteger num = 0;
    NSInteger max = maxcount;
    for (FileModel *file in _filelist) {
        if (!file.error) {
        if (file.downloadState==Downloading) {

            if (num>=max) {
				file.downloadState=WillDownload;
            }else
                num++;

        }
        }
    }
    if (num<max) {        
        for (FileModel *file in _filelist) {
             if (!file.error) {
            if (file.downloadState==WillDownload) {
                num++;
                if (num>max) {
                    break;
                }
                file.downloadState=Downloading;
            }
        }
    }
            
    }
    for (FileModel *file in _filelist) {
         if (!file.error) {
        if (file.downloadState==Downloading) {
            [self beginRequest:file isBeginDown:YES];
        }else
            [self beginRequest:file isBeginDown:NO];
         }
    }
    self.count = [_filelist count];
}

#pragma mark -- init methods --
-(id)initWithBasepath:(NSString *)basepath
TargetPathArr:(NSArray *)targetpaths{
    self.basepath = basepath;
    _targetPathArray = [[NSMutableArray alloc]initWithArray:targetpaths];
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    NSString * Max= @"1";
    if (Max==nil) {
        [userDefaults setObject:@"1" forKey:@"kMaxRequestCount"];
        Max =@"1";
    }
    [userDefaults synchronize];
    maxcount = [Max integerValue];
    _filelist = [[NSMutableArray alloc]init];
    _downinglist=[[NSMutableArray alloc] init];
    _finishedList = [[NSMutableArray alloc] init];
    self.isFistLoadSound=YES;
    return  [self init];
}

- (id)init
{
	self = [super init];
	if (self != nil) {
        self.count = 0;
        if (self.basepath!=nil) {
            [self loadFinishedfiles];
            [self loadTempfiles];
            
        }

    }
	return self;
}
-(void)cleanLastInfo{
    for (ASIHTTPRequest *request in _downinglist) {
        if([request isExecuting])
            [request cancel];
    }
    [self saveFinishedFile];
    [_downinglist removeAllObjects];
    [_finishedList removeAllObjects];
    [_filelist removeAllObjects];
   
}
+(FilesDownManage *) sharedFilesDownManageWithBasepath:(NSString *)basepath
                                         TargetPathArr:(NSArray *)targetpaths{
    @synchronized(self){
        if (sharedFilesDownManage == nil) {
            sharedFilesDownManage = [[self alloc] initWithBasepath: basepath  TargetPathArr:targetpaths];
        }
    }
    if (![sharedFilesDownManage.basepath isEqualToString:basepath]) {
        
        [sharedFilesDownManage cleanLastInfo];
        sharedFilesDownManage.basepath = basepath;
         [sharedFilesDownManage loadTempfiles];
        [sharedFilesDownManage loadFinishedfiles];
    }
   sharedFilesDownManage.basepath = basepath;
   sharedFilesDownManage.targetPathArray =[NSMutableArray arrayWithArray:targetpaths];
    return  sharedFilesDownManage;
}

+(FilesDownManage *) sharedFilesDownManage{
    @synchronized(self){
        if (sharedFilesDownManage == nil) {
            sharedFilesDownManage = [[self alloc] init];
        }
    }
    return  sharedFilesDownManage;
}
+(id) allocWithZone:(NSZone *)zone{
    @synchronized(self){
        if (sharedFilesDownManage == nil) {
            sharedFilesDownManage = [super allocWithZone:zone];
            return  sharedFilesDownManage;
        }
    }
    return nil;
}
- (void)dealloc
{
    [_targetPathArray release];
    [_downloadCompleteSound release];
    [_buttonSound release];
    [_finishedList release];
    [_downloadDelegate release];
    [_downinglist release];
    [_filelist release];
    [_fileInfo release];
    [_VCdelegate release];
    [super dealloc];
}
#pragma mark -- ASIHttpRequest回调委托 --

//出错了，如果是等待超时，则继续下载
-(void)requestFailed:(ASIHTTPRequest *)request
{
    NSError *error=[request error];
    NSLog(@"ASIHttpRequest出错了!%@",error);
    if (error.code==4) {
        return;
    }
    if ([request isExecuting]) {
        [request cancel];
    }
    FileModel *fileInfo =  [request.userInfo objectForKey:@"File"];
    fileInfo.downloadState = StopDownload;
    fileInfo.error = YES;
    for (FileModel *file in _filelist) {
        if ([file.fileName isEqualToString:fileInfo.fileName]) {
			file.downloadState = StopDownload;

            file.error = YES;
        }
    }
    [self.downloadDelegate updateCellProgress:request];
}

-(void)requestStarted:(ASIHTTPRequest *)request
{
    NSLog(@"开始了!");
}

-(void)request:(ASIHTTPRequest *)request didReceiveResponseHeaders:(NSDictionary *)responseHeaders
{
    NSLog(@"收到回复了！");

    FileModel *fileInfo=[request.userInfo objectForKey:@"File"];
  
    NSString *len = [responseHeaders objectForKey:@"Content-Length"];//
        // NSLog(@"%@,%@,%@",fileInfo.fileSize,fileInfo.fileReceivedSize,len);
    //这个信息头，首次收到的为总大小，那么后来续传时收到的大小为肯定小于或等于首次的值，则忽略
    if ([fileInfo.fileSize longLongValue]> [len longLongValue])
    {
        return;
    }
   
        fileInfo.fileSize = [NSString stringWithFormat:@"%lld",  [len longLongValue]];
        [self saveDownloadFile:fileInfo];
    
}


-(void)request:(ASIHTTPRequest *)request didReceiveBytes:(long long)bytes
{
    FileModel *fileInfo=[request.userInfo objectForKey:@"File"];
    NSLog(@"%@,%lld",fileInfo.fileReceivedSize,bytes);
    if (fileInfo.isFirstReceived) {
        fileInfo.isFirstReceived=NO;
        fileInfo.fileReceivedSize =[NSString stringWithFormat:@"%lld",bytes];
    }
    else if(!fileInfo.isFirstReceived)
    {

        fileInfo.fileReceivedSize=[NSString stringWithFormat:@"%lld",[fileInfo.fileReceivedSize longLongValue]+bytes];
    }
    
    if([self.downloadDelegate respondsToSelector:@selector(updateCellProgress:)])
    {
        [self.downloadDelegate updateCellProgress:request];
    }
    
    
   
}

//将正在下载的文件请求ASIHttpRequest从队列里移除，并将其配置文件删除掉,然后向已下载列表里添加该文件对象
-(void)requestFinished:(ASIHTTPRequest *)request
{
    [self playDownloadSound];
    FileModel *fileInfo=(FileModel *)[request.userInfo objectForKey:@"File"];
    
     [_finishedList addObject:fileInfo];
    NSString *configPath=[fileInfo.tempPath stringByAppendingString:@".plist"];
    NSFileManager *fileManager=[NSFileManager defaultManager];
    NSError *error;
    if([fileManager fileExistsAtPath:configPath])//如果存在临时文件的配置文件
    {
        [fileManager removeItemAtPath:configPath error:&error];
        if(!error)
        {
            NSLog(@"%@",[error description]);
        }
    }
    

    [_filelist removeObject:fileInfo];
    [_downinglist removeObject:request];
    [self saveFinishedFile];
    [self startLoad];
  
    if([self.downloadDelegate respondsToSelector:@selector(finishedDownload:)])
    {
        [self.downloadDelegate finishedDownload:request];
    }
}

-(void)restartAllRquests{
    
    for (ASIHTTPRequest *request in _downinglist) {
        if([request isExecuting])
            [request cancel];
    }
    
    [self startLoad];
}

@end
