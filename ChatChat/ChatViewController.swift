/*
* Copyright (c) 2015 Razeware LLC
*
* Permission is hereby granted, free of charge, to any person obtaining a copy
* of this software and associated documentation files (the "Software"), to deal
* in the Software without restriction, including without limitation the rights
* to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
* copies of the Software, and to permit persons to whom the Software is
* furnished to do so, subject to the following conditions:
*
* The above copyright notice and this permission notice shall be included in
* all copies or substantial portions of the Software.
*
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
* IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
* FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
* AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
* LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
* OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
* THE SOFTWARE.
*/

import UIKit
import Firebase
import JSQMessagesViewController

class ChatViewController: JSQMessagesViewController {
	
	let rootRef = Firebase(url: "https://cthchatchat.firebaseio.com/")
	var messageRef: Firebase!
	var userIsTypingRef: Firebase!
	private var localTyping = false
	var isTyping: Bool {
		get {
			return localTyping
		}
		set {
			localTyping = newValue
			userIsTypingRef.setValue(newValue)
		}
	}
	var userTypingQuery: FQuery!
	var messages = [JSQMessage]()
	var outgoingBubbleImageView: JSQMessagesBubbleImage!
	var incomingBubbleImageView: JSQMessagesBubbleImage!
	
	// MARK - View Load Overrides
  override func viewDidLoad() {
    super.viewDidLoad()
		
    title = "ChatChat"
		collectionView!.collectionViewLayout.incomingAvatarViewSize = CGSizeZero
		collectionView!.collectionViewLayout.outgoingAvatarViewSize = CGSizeZero
		
		messageRef = rootRef.childByAppendingPath("messages")
		setupBubbles()
  }
	override func viewDidAppear(animated: Bool) {
		super.viewDidAppear(animated)
		observeMessages()
		observeTyping()
	}
  override func viewDidDisappear(animated: Bool) {
    super.viewDidDisappear(animated)
  }
	
	// MARK - Collection View Overrides
	override func collectionView(collectionView: JSQMessagesCollectionView!, messageDataForItemAtIndexPath indexPath: NSIndexPath!) -> JSQMessageData! {
		return messages[indexPath.item]
	}
	override func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
		return messages.count
	}
	override func collectionView(collectionView: JSQMessagesCollectionView!, messageBubbleImageDataForItemAtIndexPath indexPath: NSIndexPath!) -> JSQMessageBubbleImageDataSource! {
		let message = messages[indexPath.item]
		
		if message.senderId == senderId {
			return outgoingBubbleImageView
		} else  {
			return incomingBubbleImageView
		}
	}
	override func collectionView(collectionView: JSQMessagesCollectionView!, avatarImageDataForItemAtIndexPath indexPath: NSIndexPath!) -> JSQMessageAvatarImageDataSource! {
		return nil
	}
	override func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
		let cell = super.collectionView(collectionView, cellForItemAtIndexPath: indexPath) as! JSQMessagesCollectionViewCell
		
		let message = messages[indexPath.item]
		
		if message.senderId == senderId {
			cell.textView!.textColor = UIColor.whiteColor()
		} else {
			cell.textView!.textColor = UIColor.blackColor()
		}
		return cell
	}
	
	// MARK - Functions
	private func setupBubbles() {
		let factory = JSQMessagesBubbleImageFactory()
		
		outgoingBubbleImageView = factory.outgoingMessagesBubbleImageWithColor(UIColor.jsq_messageBubbleBlueColor())
		incomingBubbleImageView = factory.incomingMessagesBubbleImageWithColor(UIColor.jsq_messageBubbleLightGrayColor())
	}
	private func observeMessages(){
		let messagesQuery = messageRef.queryLimitedToLast(25)
		messagesQuery.observeEventType(.ChildAdded) { (snapshot: FDataSnapshot!) in
			let id = snapshot.value["senderId"] as! String
			let text = snapshot.value["text"] as! String
			
			self.addMessage(id, text: text)
			self.finishReceivingMessage()
		}
	}
	private func observeTyping() {
		let typingIndicatorRef = rootRef.childByAppendingPath("typingIndicator")
		userIsTypingRef = typingIndicatorRef.childByAppendingPath(senderId)
		userIsTypingRef.onDisconnectRemoveValue()
		
		userTypingQuery = typingIndicatorRef.queryOrderedByValue().queryEqualToValue(true)
		userTypingQuery.observeEventType(.Value) { (data: FDataSnapshot!) in
			if data.childrenCount == 1 && self.isTyping { return }
			
			self.showTypingIndicator = data.childrenCount > 0
			self.scrollToBottomAnimated(true)
		}
	}
	func addMessage(id: String, text: String) {
		let message = JSQMessage(senderId: id, displayName: "", text: text)
		messages.append(message)
	}
	
	// MARK - Actions
	override func didPressSendButton(button: UIButton!, withMessageText text: String!, senderId: String!, senderDisplayName: String!, date: NSDate!) {
		let itemRef = messageRef.childByAutoId()
		let messageItem = ["text": text, "senderId": senderId]
		
		itemRef.setValue(messageItem)
		JSQSystemSoundPlayer.jsq_playMessageSentSound()
		
		isTyping = false
		finishSendingMessage()
	}
	override func textViewDidChange(textView: UITextView) {
		super.textViewDidChange(textView)
		
		isTyping = textView.text != ""
	}
}