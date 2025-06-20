<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ page import="java.sql.*, java.util.*, java.util.regex.*, java.io.*, java.security.MessageDigest" %>
<%@ page import="jakarta.servlet.http.Part" %>
<%@ include file="db.jsp" %>
<%
    request.setCharacterEncoding("UTF-8");
%>
<%! 
    private static final String[] ALLOWED_EXT = {
        "jpg", "jpeg", "png", "gif", "bmp", "webp"
    };
    private static final String[] ALLOWED_MIME = {
        "image/jpeg", "image/png", "image/gif", "image/bmp", "image/webp"
    };

    private boolean checkAllowedExt(String filename) {
        if (filename == null) return false;
        String lower = filename.toLowerCase();
        for (String ext : ALLOWED_EXT) {
            if (lower.endsWith("." + ext)) return true;
        }
        return false;
    }
    private boolean checkAllowedMime(String mime) {
        if (mime == null) return false;
        for (String m : ALLOWED_MIME) {
            if (mime.equalsIgnoreCase(m)) return true;
        }
        return false;
    }
    private boolean checkMagicNumber(InputStream is) throws Exception {
        byte[] buf = new byte[8];
        int len = is.read(buf);
        if (len < 4) return false;
        // JPEG: FF D8 FF
        if (buf[0]==(byte)0xFF && buf[1]==(byte)0xD8 && buf[2]==(byte)0xFF) return true;
        // PNG: 89 50 4E 47
        if (buf[0]==(byte)0x89 && buf[1]==(byte)0x50 && buf[2]==(byte)0x4E && buf[3]==(byte)0x47) return true;
        // GIF: 47 49 46 38
        if (buf[0]==(byte)0x47 && buf[1]==(byte)0x49 && buf[2]==(byte)0x46 && buf[3]==(byte)0x38) return true;
        // BMP: 42 4D
        if (buf[0]==(byte)0x42 && buf[1]==(byte)0x4D) return true;
        // WebP: 52 49 46 46....57 45 42 50
        if (buf[0]==(byte)0x52 && buf[1]==(byte)0x49 && buf[2]==(byte)0x46 && buf[3]==(byte)0x46) return true;
        return false;
    }
    private String sha512(String pw) throws Exception {
        MessageDigest md = MessageDigest.getInstance("SHA-512");
        byte[] bytes = md.digest(pw.getBytes("UTF-8"));
        StringBuilder sb = new StringBuilder();
        for (byte b : bytes) {
            sb.append(String.format("%02x", b));
        }
        return sb.toString();
    }
%>
<%
    if (!"POST".equalsIgnoreCase(request.getMethod())) {
        return;
    }

    // CSRF 검증
    String sessionToken = (String) session.getAttribute("csrf_token");
    String formToken = null;
    String contentType = request.getContentType();
    if (contentType != null && contentType.toLowerCase().startsWith("multipart/")) {
        Part tokenPart = request.getPart("csrf_token");
        if (tokenPart != null) {
            BufferedReader reader = new BufferedReader(new InputStreamReader(tokenPart.getInputStream(), "UTF-8"));
            StringBuilder sb = new StringBuilder();
            String line;
            while ((line = reader.readLine()) != null) sb.append(line);
            formToken = sb.toString();
        }
    } else {
        formToken = request.getParameter("csrf_token");
    }
    if (sessionToken == null || formToken == null || !sessionToken.equals(formToken)) {
%>
        <script>
            alert('잘못된 접근입니다.');
            history.back();
        </script>
<%
        return;
    }
    session.removeAttribute("csrf_token");

    String username = request.getParameter("username");
    String email = request.getParameter("email");
    String phoneNum = request.getParameter("phonenum");
    int idx = session.getAttribute("idx") != null ? Integer.parseInt(session.getAttribute("idx").toString()) : 0;
    String removeFlag = request.getParameter("removeImage") != null ? request.getParameter("removeImage") : "0";
    String pw = request.getParameter("pw");

    // ★ 이름 중복 체크 ★
    String dupSql = "SELECT COUNT(*) AS cnt FROM user_table WHERE user_id = ? AND user_idx != ?";
    PreparedStatement dupStmt = db_conn.prepareStatement(dupSql);
    dupStmt.setString(1, username);
    dupStmt.setInt(2, idx);
    ResultSet dupRs = dupStmt.executeQuery();
    if (dupRs.next() && dupRs.getInt("cnt") > 0) {
%>
        <script>
            alert('이미 사용 중인 이름입니다.');
            history.back();
        </script>
<%
        return;
    }
    dupRs.close();
    dupStmt.close();

    // 유효성 검사
    if (username == null || username.trim().isEmpty()) {
%>
        <script>
            alert('이름(아이디) 칸을 비워둘 수 없습니다.');
            history.back();
        </script>
<%
        return;
    }
    if (email == null || !email.matches("^[\\w._%+-]+@[\\w.-]+\\.[a-zA-Z]{2,}$")) {
%>
        <script>
            alert('이메일 형식이 맞지 않습니다.');
            history.back();
        </script>
<%
        return;
    }
    if (phoneNum == null || !phoneNum.matches("^\\d{3}-\\d{4}-\\d{4}$")) {
%>
        <script>
            alert('전화번호 형식이 맞지 않습니다.');
            history.back();
        </script>
<%
        return;
    }

    String sql = null;
    InputStream imageBlob = null;
    String imageFileName = null;

    // 기존 이미지 제거 요청 (DB의 blob 제거)
    if ("1".equals(removeFlag)) {
        sql = "UPDATE user_table SET user_id = ?, user_email = ?, user_phonenum = ?, profile_image_blob = NULL, profile_image_name = NULL WHERE user_idx = ?";
    }
    // 새 이미지 업로드 (blob으로 저장, 화이트리스트 기반 검증)
    else if (request.getPart("profileImage") != null && request.getPart("profileImage").getSize() > 0) {
        Part imageFile = request.getPart("profileImage");
        String fileName = imageFile.getSubmittedFileName();

        // [1] 확장자 체크
        if (!checkAllowedExt(fileName)) {
%>
            <script>
                alert('이미지 파일만 업로드할 수 있습니다.');
                history.back();
            </script>
<%
            return;
        }

        // [2] MIME 타입 체크
        String mimeType = imageFile.getContentType();
        if (!checkAllowedMime(mimeType)) {
%>
            <script>
                alert('이미지 파일만 업로드할 수 있습니다.');
                history.back();
            </script>
<%
            return;
        }

        // [3] Magic number(시그니처) 체크
        InputStream imgIs = imageFile.getInputStream();
        if (!checkMagicNumber(imgIs)) {
            imgIs.close();
%>
            <script>
                alert('실제 이미지 파일만 업로드할 수 있습니다.');
                history.back();
            </script>
<%
            return;
        }
        imgIs.close();

        // BLOB로 저장
        imageBlob = imageFile.getInputStream();
        imageFileName = fileName;

        sql = "UPDATE user_table SET user_id = ?, user_email = ?, user_phonenum = ?, profile_image_blob = ?, profile_image_name = ? WHERE user_idx = ?";
    }
    // 비밀번호 변경만
    else if (pw != null && !pw.isEmpty()) {
        // 1. 아이디와 동일한 비밀번호 방지
        if (pw.equals(username)) {
%>
            <script>
                alert('비밀번호는 아이디와 동일하게 설정할 수 없습니다.');
                history.back();
            </script>
<%
            return;
        }
        // 2. SHA-512 해시 적용
        String hashedPw = "";
        try {
            hashedPw = sha512(pw);
        } catch (Exception e) {
%>
            <script>
                alert('비밀번호 해싱 중 오류가 발생했습니다.');
                history.back();
            </script>
<%
            return;
        }
        sql = "UPDATE user_table SET user_id = ?, user_email = ?, user_phonenum = ?, user_password = ? WHERE user_idx = ?";
    } else {
        sql = "UPDATE user_table SET user_id = ?, user_email = ?, user_phonenum = ? WHERE user_idx = ?";
    }

    PreparedStatement pstmt = null;
    int result = 0;
    try {
        if ("1".equals(removeFlag)) {
            pstmt = db_conn.prepareStatement(sql);
            pstmt.setString(1, username);
            pstmt.setString(2, email);
            pstmt.setString(3, phoneNum);
            pstmt.setInt(4, idx);
        } else if (imageBlob != null) {
            pstmt = db_conn.prepareStatement(sql);
            pstmt.setString(1, username);
            pstmt.setString(2, email);
            pstmt.setString(3, phoneNum);
            pstmt.setBlob(4, imageBlob);
            pstmt.setString(5, imageFileName);
            pstmt.setInt(6, idx);
        } else if (pw != null && !pw.isEmpty()) {
            pstmt = db_conn.prepareStatement(sql);
            pstmt.setString(1, username);
            pstmt.setString(2, email);
            pstmt.setString(3, phoneNum);
            pstmt.setString(4, sha512(pw)); // SHA-512 해시 적용
            pstmt.setInt(5, idx);
        } else {
            pstmt = db_conn.prepareStatement(sql);
            pstmt.setString(1, username);
            pstmt.setString(2, email);
            pstmt.setString(3, phoneNum);
            pstmt.setInt(4, idx);
        }
        result = pstmt.executeUpdate();
    } finally {
        if (pstmt != null) pstmt.close();
        if (imageBlob != null) imageBlob.close();
    }

    if (result > 0) {
        // 세션 갱신
        session.setAttribute("username", username);
        session.setAttribute("email", email);
        session.setAttribute("phonenum", phoneNum);
        if ("1".equals(removeFlag)) {
            session.removeAttribute("profile_image");
        } else if (imageFileName != null) {
            session.setAttribute("profile_image", "profile_image_view.jsp?uid=" + idx);
        }
%>
        <script>
            alert('변경 사항을 저장하였습니다.');
            window.location.href = 'mypage.jsp';
        </script>
<%
    } else {
%>
        <script>
            alert('변경 사항 저장 중 오류가 발생하였습니다.');
            history.back();
        </script>
<%
    }
%>
