import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/user_model.dart';

class ChatInformation extends StatefulWidget {
  final String chatId;
  final String chatName;
  final String chatImage;
  final bool isGroup;
  final List<Map<String, dynamic>> members;
  final UserModel? otherUser;

  const ChatInformation({
    Key? key,
    required this.chatId,
    required this.chatName,
    required this.chatImage,
    required this.isGroup,
    required this.members,
    this.otherUser,
  }) : super(key: key);

  @override
  State<ChatInformation> createState() => _ChatInformationState();
}

class _ChatInformationState extends State<ChatInformation> {
  bool isMuted = false;
  bool isBlocked = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Thông tin',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(),
            const SizedBox(height: 20),
            _buildActionButtons(),
            const SizedBox(height: 20),
            Container(height: 8, color: Colors.grey[200]),
            if (widget.isGroup) ...[
              _buildMembersSection(),
              Container(height: 8, color: Colors.grey[200]),
            ],
            _buildOptionsSection(),
            Container(height: 8, color: Colors.grey[200]),
            _buildMediaSection(),
            Container(height: 8, color: Colors.grey[200]),
            _buildDangerSection(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        const SizedBox(height: 20),
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(50),
            child: widget.chatImage.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: widget.chatImage,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: Colors.grey[300],
                      child: const Icon(Icons.person, size: 50),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: Colors.grey[300],
                      child: const Icon(Icons.person, size: 50),
                    ),
                  )
                : Container(
                    color: Colors.grey[300],
                    child: const Icon(Icons.person, size: 50),
                  ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          widget.chatName,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        if (widget.otherUser != null)
          Text(
            widget.otherUser!.email,
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          )
        else
          Text(
            widget.isGroup
                ? '${widget.members.length} thành viên'
                : 'Đang hoạt động',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildActionButton(
            icon: Icons.call,
            label: 'Gọi',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Tính năng gọi sẽ sớm có')),
              );
            },
          ),
          _buildActionButton(
            icon: Icons.videocam,
            label: 'Video',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Tính năng video sẽ sớm có')),
              );
            },
          ),
          _buildActionButton(
            icon: Icons.info_outline,
            label: 'Thông tin',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Đang xem thông tin')),
              );
            },
          ),
          _buildActionButton(
            icon: Icons.search,
            label: 'Tìm kiếm',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Tính năng tìm kiếm sẽ sớm có')),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.black87, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.black87),
          ),
        ],
      ),
    );
  }

  Widget _buildMembersSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Thành viên (${widget.members.length})',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              GestureDetector(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Thêm thành viên')),
                  );
                },
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add, size: 18),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: widget.members.length,
            itemBuilder: (context, index) {
              final member = widget.members[index];
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Column(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(30),
                        child: (member['avatar'] as String?)?.isNotEmpty ?? false
                            ? CachedNetworkImage(
                                imageUrl: member['avatar'] ?? '',
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  color: Colors.grey[300],
                                  child: const Icon(Icons.person),
                                ),
                                errorWidget: (context, url, error) =>
                                    Container(
                                  color: Colors.grey[300],
                                  child: const Icon(Icons.person),
                                ),
                              )
                            : Container(
                                color: Colors.grey[300],
                                child: const Icon(Icons.person),
                              ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: 60,
                      child: Text(
                        member['name'] ?? 'Người dùng',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildOptionsSection() {
    return Column(
      children: [
        _buildOptionTile(
          icon: Icons.notifications_off,
          title: 'Tắt thông báo',
          subtitle: 'Bạn sẽ không nhận được thông báo từ cuộc trò chuyện này',
          value: isMuted,
          onChanged: (value) {
            setState(() => isMuted = value);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  value ? 'Đã tắt thông báo' : 'Đã bật thông báo',
                ),
              ),
            );
          },
        ),
        _buildOptionTile(
          icon: Icons.block,
          title: 'Chặn',
          subtitle: 'Bạn sẽ không nhận được tin nhắn từ người này',
          value: isBlocked,
          onChanged: (value) {
            setState(() => isBlocked = value);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  value ? 'Đã chặn người dùng' : 'Đã bỏ chặn người dùng',
                ),
              ),
            );
          },
        ),
        _buildOptionTile(
          icon: Icons.star_border,
          title: 'Đánh dấu sao',
          subtitle: 'Thêm cuộc trò chuyện này vào danh sách ưa thích',
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Đã đánh dấu sao')),
            );
          },
        ),
        _buildOptionTile(
          icon: Icons.edit,
          title: 'Đổi tên',
          subtitle: 'Đặt tên riêng cho cuộc trò chuyện này',
          onTap: () {
            _showRenameDialog();
          },
        ),
      ],
    );
  }

  Widget _buildMediaSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: const Text(
            'Tệp, ảnh, liên kết',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMediaCategory(
                icon: Icons.image,
                label: 'Ảnh',
                count: 0,
              ),
              _buildMediaCategory(
                icon: Icons.video_library,
                label: 'Video',
                count: 0,
              ),
              _buildMediaCategory(
                icon: Icons.link,
                label: 'Liên kết',
                count: 0,
              ),
              _buildMediaCategory(
                icon: Icons.description,
                label: 'Tệp',
                count: 0,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMediaCategory({
    required IconData icon,
    required String label,
    required int count,
  }) {
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.black87, size: 28),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
        Text(
          '$count',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildDangerSection() {
    return Column(
      children: [
        _buildOptionTile(
          icon: Icons.delete_outline,
          title: 'Xóa cuộc trò chuyện',
          subtitle: 'Xóa tất cả tin nhắn trong cuộc trò chuyện này',
          textColor: Colors.red,
          onTap: () {
            _showDeleteDialog();
          },
        ),
        _buildOptionTile(
          icon: Icons.report_problem_outlined,
          title: 'Báo cáo',
          subtitle: 'Báo cáo cuộc trò chuyện này cho chúng tôi',
          textColor: Colors.red,
          onTap: () {
            _showReportDialog();
          },
        ),
      ],
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    String? subtitle,
    Color? textColor,
    bool value = false,
    ValueChanged<bool>? onChanged,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(icon, color: textColor ?? Colors.black87, size: 24),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: textColor ?? Colors.black,
                      ),
                    ),
                    if (subtitle != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (onChanged != null)
                Switch(
                  value: value,
                  onChanged: onChanged,
                  activeColor: Colors.blue,
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRenameDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Đổi tên cuộc trò chuyện'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Nhập tên mới',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Đã đổi tên thành: ${controller.text}'),
                ),
              );
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa cuộc trò chuyện?'),
        content: const Text(
          'Bạn có chắc chắn muốn xóa cuộc trò chuyện này? Hành động này không thể hoàn tác.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Đã xóa cuộc trò chuyện')),
              );
            },
            child: const Text('Xóa', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showReportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Báo cáo cuộc trò chuyện'),
        content: const Text(
          'Vui lòng cho chúng tôi biết lý do bạn muốn báo cáo cuộc trò chuyện này.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Đã gửi báo cáo')),
              );
            },
            child: const Text('Báo cáo'),
          ),
        ],
      ),
    );
  }
}
