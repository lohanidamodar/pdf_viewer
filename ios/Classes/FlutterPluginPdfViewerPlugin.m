#import "FlutterPluginPdfViewerPlugin.h"
#import <CommonCrypto/CommonDigest.h>

static NSString* const kDirectory = @"FlutterPluginPdfViewer";
static NSString* const kFilePath = @"file:///";

@implementation FlutterPluginPdfViewerPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  FlutterMethodChannel* channel = [FlutterMethodChannel
      methodChannelWithName:@"flutter_plugin_pdf_viewer"
            binaryMessenger:[registrar messenger]];
  FlutterPluginPdfViewerPlugin* instance = [[FlutterPluginPdfViewerPlugin alloc] init];
  [registrar addMethodCallDelegate:instance channel:channel];
}

- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
          if ([@"getPage" isEqualToString:call.method]) {
              size_t pageNumber = (size_t)[call.arguments[@"pageNumber"] intValue];
              NSString * filePath = call.arguments[@"filePath"];
              result([self getPage:filePath ofPage:pageNumber]);
          } else if ([@"getNumberOfPages" isEqualToString:call.method]) {
              NSString * filePath = call.arguments[@"filePath"];
              result([self getNumberOfPages:filePath]);
          }
          else {
              result(FlutterMethodNotImplemented);
          }
      });
}

-(NSString *)getNumberOfPages:(NSString *)url
{
    NSURL * sourcePDFUrl;
    if([url containsString:kFilePath]){
        sourcePDFUrl = [NSURL URLWithString:url];
    }else{
        sourcePDFUrl = [NSURL URLWithString:[kFilePath stringByAppendingString:url]];
    }
    CGPDFDocumentRef SourcePDFDocument = CGPDFDocumentCreateWithURL((__bridge CFURLRef)sourcePDFUrl);
    size_t numberOfPages = CGPDFDocumentGetNumberOfPages(SourcePDFDocument);
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *temporaryDirectory = [paths objectAtIndex:0];
    NSString *filePathAndDirectory = [temporaryDirectory stringByAppendingPathComponent:kDirectory];
    NSError *error;

    // Clear cache folder
    if ([[NSFileManager defaultManager] fileExistsAtPath:filePathAndDirectory]) {
        NSLog(@"[FlutterPluginPDFViewer] Removing old documents cache");
        [[NSFileManager defaultManager] removeItemAtPath:filePathAndDirectory error:&error];
    }

    if (![[NSFileManager defaultManager] createDirectoryAtPath:filePathAndDirectory
                                   withIntermediateDirectories:YES
                                                    attributes:nil
                                                         error:&error])
    {
        NSLog(@"Create directory error: %@", error);
        return nil;
    }
    return [NSString stringWithFormat:@"%zd", numberOfPages];
}

-(NSString*)getPage:(NSString *)url ofPage:(size_t)pageNumber
{
    NSURL * sourcePDFUrl;
    if([url containsString:kFilePath]){
        sourcePDFUrl = [NSURL URLWithString:url];
    }else{
        sourcePDFUrl = [NSURL URLWithString:[kFilePath stringByAppendingString:url]];
    }
    CGPDFDocumentRef SourcePDFDocument = CGPDFDocumentCreateWithURL((__bridge CFURLRef)sourcePDFUrl);
    size_t numberOfPages = CGPDFDocumentGetNumberOfPages(SourcePDFDocument);
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *temporaryDirectory = [paths objectAtIndex:0];
    NSString *filePathAndDirectory = [temporaryDirectory stringByAppendingPathComponent:kDirectory];
    NSError *error;

    if (pageNumber > numberOfPages) {
        pageNumber = numberOfPages;
    }
    NSString *fileName = [NSString stringWithFormat:@"%@_%ld", [self getmd5WithString:url], pageNumber];
    NSString *imageFilePath = [filePathAndDirectory stringByAppendingPathComponent:fileName];
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:imageFilePath]) {
        CGPDFDocumentRelease(SourcePDFDocument);
        return imageFilePath;
    }

    if (![[NSFileManager defaultManager] createDirectoryAtPath:filePathAndDirectory
                                   withIntermediateDirectories:YES
                                                    attributes:nil
                                                         error:&error])
    {
        NSLog(@"Create directory error: %@", error);
        CGPDFDocumentRelease(SourcePDFDocument);
        return nil;
    }
    CGPDFPageRef SourcePDFPage = CGPDFDocumentGetPage(SourcePDFDocument, pageNumber);
    CGRect sourceRect = CGPDFPageGetBoxRect(SourcePDFPage, kCGPDFMediaBox);
    // Calculate resolution
    // Set DPI to 300
    CGFloat dpi = 2;
    CGFloat width = sourceRect.size.width * dpi;
    CGFloat height = sourceRect.size.height * dpi;
    UIGraphicsBeginImageContext(CGSizeMake(width, height));
    // Fill Background
    CGContextRef currentContext = UIGraphicsGetCurrentContext();
    // Change interpolation settings
    CGContextSetInterpolationQuality(currentContext, kCGInterpolationHigh);
    // Fill background with white color
    CGContextSetRGBFillColor(currentContext, 1.0f, 1.0f, 1.0f, 1.0f);
    CGContextFillRect(currentContext, CGContextGetClipBoundingBox(currentContext));
    CGContextTranslateCTM(currentContext, 0.0, height);
    CGContextScaleCTM(currentContext, dpi, -dpi);
    CGContextSaveGState(currentContext);
    CGContextDrawPDFPage (currentContext, SourcePDFPage);
    
    CGContextRestoreGState(currentContext);
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    CGPDFDocumentRelease(SourcePDFDocument);
    [UIImageJPEGRepresentation(image, 0.7) writeToFile: imageFilePath atomically:YES];
    return imageFilePath;
}

- (NSString*)getmd5WithString:(NSString *)string {
    const char* original_str=[string UTF8String];
    unsigned char digist[CC_MD5_DIGEST_LENGTH]; //CC_MD5_DIGEST_LENGTH = 16
    CC_MD5(original_str, (uint)strlen(original_str), digist);
    NSMutableString* outPutStr = [NSMutableString stringWithCapacity:10];
    for(int i = 0; i < CC_MD5_DIGEST_LENGTH; i++){
        [outPutStr appendFormat:@"%02x", digist[i]];//小写x表示输出的是小写MD5，大写X表示输出的是大写MD5
    }
    return [outPutStr lowercaseString];
}


@end
